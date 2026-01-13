// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const t = @import("types.zig");

pub const Wire = struct {
    pub const header_len: usize = 4 + 1 + 2;
};

pub const Writer = struct {
    buf: []u8,
    idx: usize,

    pub fn init(buf: []u8) Writer {
        return .{ .buf = buf, .idx = 0 };
    }

    fn need(self: *Writer, n: usize) !void {
        if (self.idx + n > self.buf.len) return t.EncodeError.NoSpace;
    }

    pub fn writeU8(self: *Writer, v: u8) !void {
        try self.need(1);
        self.buf[self.idx] = v;
        self.idx += 1;
    }

    pub fn writeU16(self: *Writer, v: u16) !void {
        try self.need(2);
        std.mem.writeInt(u16, self.buf[self.idx .. self.idx + 2], v, .little);
        self.idx += 2;
    }

    pub fn writeU32(self: *Writer, v: u32) !void {
        try self.need(4);
        std.mem.writeInt(u32, self.buf[self.idx .. self.idx + 4], v, .little);
        self.idx += 4;
    }

    pub fn writeU64(self: *Writer, v: u64) !void {
        try self.need(8);
        std.mem.writeInt(u64, self.buf[self.idx .. self.idx + 8], v, .little);
        self.idx += 8;
    }

    pub fn writeBytes(self: *Writer, b: []const u8) !void {
        try self.need(b.len);
        @memcpy(self.buf[self.idx .. self.idx + b.len], b);
        self.idx += b.len;
    }

    pub fn writeString(self: *Writer, s: []const u8) !void {
        if (s.len > 0xFFFF) return t.EncodeError.StringTooLong;
        try self.writeU16(@intCast(s.len));
        try self.writeBytes(s);
    }

    pub fn writeQid(self: *Writer, q: t.Qid) !void {
        try self.writeU8(q.qtype);
        try self.writeU32(q.vers);
        try self.writeU64(q.path);
    }
};

pub const Reader = struct {
    buf: []const u8,
    idx: usize,

    pub fn init(buf: []const u8) Reader {
        return .{ .buf = buf, .idx = 0 };
    }

    fn need(self: *Reader, n: usize) !void {
        if (self.idx + n > self.buf.len) return t.DecodeError.Short;
    }

    pub fn readU8(self: *Reader) !u8 {
        try self.need(1);
        const v = self.buf[self.idx];
        self.idx += 1;
        return v;
    }

    pub fn readU16(self: *Reader) !u16 {
        try self.need(2);
        const v = std.mem.readInt(u16, self.buf[self.idx .. self.idx + 2], .little);
        self.idx += 2;
        return v;
    }

    pub fn readU32(self: *Reader) !u32 {
        try self.need(4);
        const v = std.mem.readInt(u32, self.buf[self.idx .. self.idx + 4], .little);
        self.idx += 4;
        return v;
    }

    pub fn readU64(self: *Reader) !u64 {
        try self.need(8);
        const v = std.mem.readInt(u64, self.buf[self.idx .. self.idx + 8], .little);
        self.idx += 8;
        return v;
    }

    pub fn readBytes(self: *Reader, n: usize) ![]const u8 {
        try self.need(n);
        const out = self.buf[self.idx .. self.idx + n];
        self.idx += n;
        return out;
    }

    pub fn readString(self: *Reader) ![]const u8 {
        const n = try self.readU16();
        return try self.readBytes(@intCast(n));
    }

    pub fn readQid(self: *Reader) !t.Qid {
        return .{
            .qtype = try self.readU8(),
            .vers = try self.readU32(),
            .path = try self.readU64(),
        };
    }
};

pub fn decodeHeader(frame: []const u8) !t.Header {
    if (frame.len < Wire.header_len) return t.DecodeError.Short;

    const size = std.mem.readInt(u32, frame[0..4], .little);
    if (size < Wire.header_len) return t.DecodeError.BadSize;
    if (size > frame.len) return t.DecodeError.Short;

    const mtype_u8 = frame[4];
    const tag = std.mem.readInt(u16, frame[5..7], .little);

    _ = t.msgTypeFromU8(mtype_u8) orelse return t.DecodeError.BadType;

    return .{ .size = size, .mtype = mtype_u8, .tag = tag };
}

pub fn payloadSlice(frame: []const u8, hdr: t.Header) []const u8 {
    const sz: usize = @intCast(hdr.size);
    return frame[Wire.header_len..sz];
}

pub fn beginMessage(buf: []u8, mtype: t.MsgType, tag: u16) !Writer {
    var w = Writer.init(buf);
    try w.writeU32(0);
    try w.writeU8(@intFromEnum(mtype));
    try w.writeU16(tag);
    return w;
}

pub fn finishMessage(buf: []u8, w: *Writer) []const u8 {
    const size_u32: u32 = @intCast(w.idx);
    std.mem.writeInt(u32, buf[0..4], size_u32, .little);
    return buf[0..w.idx];
}

pub fn encodeTversion(buf: []u8, tag: u16, msize: u32, version: []const u8) ![]const u8 {
    var w = try beginMessage(buf, .Tversion, tag);
    try w.writeU32(msize);
    try w.writeString(version);
    return finishMessage(buf, &w);
}

pub fn encodeRversion(buf: []u8, tag: u16, msize: u32, version: []const u8) ![]const u8 {
    var w = try beginMessage(buf, .Rversion, tag);
    try w.writeU32(msize);
    try w.writeString(version);
    return finishMessage(buf, &w);
}

pub fn encodeTattach(buf: []u8, tag: u16, fid: u32, afid: u32, uname: []const u8, aname: []const u8) ![]const u8 {
    var w = try beginMessage(buf, .Tattach, tag);
    try w.writeU32(fid);
    try w.writeU32(afid);
    try w.writeString(uname);
    try w.writeString(aname);
    return finishMessage(buf, &w);
}

pub fn encodeRattach(buf: []u8, tag: u16, qid: t.Qid) ![]const u8 {
    var w = try beginMessage(buf, .Rattach, tag);
    try w.writeQid(qid);
    return finishMessage(buf, &w);
}

pub fn encodeRerror(buf: []u8, tag: u16, ename: []const u8) ![]const u8 {
    var w = try beginMessage(buf, .Rerror, tag);
    try w.writeString(ename);
    return finishMessage(buf, &w);
}

pub fn encodeTwalk1(buf: []u8, tag: u16, fid: u32, newfid: u32, name: []const u8) ![]const u8 {
    var w = try beginMessage(buf, .Twalk, tag);
    try w.writeU32(fid);
    try w.writeU32(newfid);
    try w.writeU16(1);
    try w.writeString(name);
    return finishMessage(buf, &w);
}

pub fn encodeRwalk0(buf: []u8, tag: u16) ![]const u8 {
    var w = try beginMessage(buf, .Rwalk, tag);
    try w.writeU16(0);
    return finishMessage(buf, &w);
}

pub fn encodeRwalk1(buf: []u8, tag: u16, qid: t.Qid) ![]const u8 {
    var w = try beginMessage(buf, .Rwalk, tag);
    try w.writeU16(1);
    try w.writeQid(qid);
    return finishMessage(buf, &w);
}

pub fn encodeTopen(buf: []u8, tag: u16, fid: u32, mode: u8) ![]const u8 {
    var w = try beginMessage(buf, .Topen, tag);
    try w.writeU32(fid);
    try w.writeU8(mode);
    return finishMessage(buf, &w);
}

pub fn encodeRopen(buf: []u8, tag: u16, qid: t.Qid, iounit: u32) ![]const u8 {
    var w = try beginMessage(buf, .Ropen, tag);
    try w.writeQid(qid);
    try w.writeU32(iounit);
    return finishMessage(buf, &w);
}

pub fn encodeTread(buf: []u8, tag: u16, fid: u32, offset: u64, count: u32) ![]const u8 {
    var w = try beginMessage(buf, .Tread, tag);
    try w.writeU32(fid);
    try w.writeU64(offset);
    try w.writeU32(count);
    return finishMessage(buf, &w);
}

pub fn encodeRread(buf: []u8, tag: u16, data: []const u8) ![]const u8 {
    var w = try beginMessage(buf, .Rread, tag);
    try w.writeU32(@intCast(data.len));
    try w.writeBytes(data);
    return finishMessage(buf, &w);
}

pub fn encodeTwrite(buf: []u8, tag: u16, fid: u32, offset: u64, data: []const u8) ![]const u8 {
    var w = try beginMessage(buf, .Twrite, tag);
    try w.writeU32(fid);
    try w.writeU64(offset);
    try w.writeU32(@intCast(data.len));
    try w.writeBytes(data);
    return finishMessage(buf, &w);
}

pub fn encodeRwrite(buf: []u8, tag: u16, count: u32) ![]const u8 {
    var w = try beginMessage(buf, .Rwrite, tag);
    try w.writeU32(count);
    return finishMessage(buf, &w);
}

pub fn encodeTclunk(buf: []u8, tag: u16, fid: u32) ![]const u8 {
    var w = try beginMessage(buf, .Tclunk, tag);
    try w.writeU32(fid);
    return finishMessage(buf, &w);
}

pub fn encodeRclunk(buf: []u8, tag: u16) ![]const u8 {
    var w = try beginMessage(buf, .Rclunk, tag);
    return finishMessage(buf, &w);
}

pub fn decodeTversion(frame: []const u8) !struct { tag: u16, msize: u32, version: []const u8 } {
    const hdr = try decodeHeader(frame);
    if (t.msgTypeFromU8(hdr.mtype).? != .Tversion) return t.DecodeError.BadType;
    var r = Reader.init(payloadSlice(frame, hdr));
    return .{ .tag = hdr.tag, .msize = try r.readU32(), .version = try r.readString() };
}

pub fn decodeTattach(frame: []const u8) !struct { tag: u16, fid: u32, afid: u32, uname: []const u8, aname: []const u8 } {
    const hdr = try decodeHeader(frame);
    if (t.msgTypeFromU8(hdr.mtype).? != .Tattach) return t.DecodeError.BadType;
    var r = Reader.init(payloadSlice(frame, hdr));
    return .{
        .tag = hdr.tag,
        .fid = try r.readU32(),
        .afid = try r.readU32(),
        .uname = try r.readString(),
        .aname = try r.readString(),
    };
}

pub fn decodeTwalk(frame: []const u8) !struct { tag: u16, fid: u32, newfid: u32, nwname: u16, wname: [t.WalkMax][]const u8 } {
    const hdr = try decodeHeader(frame);
    if (t.msgTypeFromU8(hdr.mtype).? != .Twalk) return t.DecodeError.BadType;
    var r = Reader.init(payloadSlice(frame, hdr));
    const fid = try r.readU32();
    const newfid = try r.readU32();
    const nwname = try r.readU16();
    if (nwname > t.WalkMax) return t.DecodeError.BadString;

    var names: [t.WalkMax][]const u8 = undefined;
    var i: usize = 0;
    while (i < nwname) : (i += 1) names[i] = try r.readString();
    while (i < t.WalkMax) : (i += 1) names[i] = "";

    return .{ .tag = hdr.tag, .fid = fid, .newfid = newfid, .nwname = nwname, .wname = names };
}

pub fn decodeTopen(frame: []const u8) !struct { tag: u16, fid: u32, mode: u8 } {
    const hdr = try decodeHeader(frame);
    if (t.msgTypeFromU8(hdr.mtype).? != .Topen) return t.DecodeError.BadType;
    var r = Reader.init(payloadSlice(frame, hdr));
    return .{ .tag = hdr.tag, .fid = try r.readU32(), .mode = try r.readU8() };
}

pub fn decodeTread(frame: []const u8) !struct { tag: u16, fid: u32, offset: u64, count: u32 } {
    const hdr = try decodeHeader(frame);
    if (t.msgTypeFromU8(hdr.mtype).? != .Tread) return t.DecodeError.BadType;
    var r = Reader.init(payloadSlice(frame, hdr));
    return .{ .tag = hdr.tag, .fid = try r.readU32(), .offset = try r.readU64(), .count = try r.readU32() };
}

pub fn decodeTwrite(frame: []const u8) !struct { tag: u16, fid: u32, offset: u64, data: []const u8 } {
    const hdr = try decodeHeader(frame);
    if (t.msgTypeFromU8(hdr.mtype).? != .Twrite) return t.DecodeError.BadType;
    var r = Reader.init(payloadSlice(frame, hdr));
    const fid = try r.readU32();
    const offset = try r.readU64();
    const count = try r.readU32();
    const data = try r.readBytes(@intCast(count));
    return .{ .tag = hdr.tag, .fid = fid, .offset = offset, .data = data };
}

pub fn decodeTclunk(frame: []const u8) !struct { tag: u16, fid: u32 } {
    const hdr = try decodeHeader(frame);
    if (t.msgTypeFromU8(hdr.mtype).? != .Tclunk) return t.DecodeError.BadType;
    var r = Reader.init(payloadSlice(frame, hdr));
    return .{ .tag = hdr.tag, .fid = try r.readU32() };
}
