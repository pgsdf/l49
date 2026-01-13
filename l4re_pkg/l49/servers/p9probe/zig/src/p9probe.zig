// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const types = @import("../../../../../src/p9/types.zig");
const codec = @import("../../../../../src/p9/codec.zig");

extern fn l49_puts(s: [*:0]const u8) void;
extern fn l49_ipc_send(endpoint_cap: u32, msg: *const u8, msg_len: usize) c_int;
extern fn l49_ipc_recv(endpoint_cap: u32, buf: *u8, buf_cap: usize, out_len: *usize) c_int;

fn cstr(comptime s: []const u8) [*:0]const u8 {
    return s ++ "\x00";
}

fn log(comptime s: []const u8) void {
    l49_puts(cstr(s));
}

pub const InlineMax: usize = 1024;

pub const TransportHeader = packed struct {
    magic: u32 = 0x3934504C,
    version: u16 = 0x0001,
    flags: u16 = 0,
    msg_len: u32 = 0,
    aux: u32 = 0,
    reserved: u32 = 0,
};

const Transport = struct {
    ep: u32,
    tx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,
    rx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,

    fn call(self: *Transport, p9req: []const u8) ![]const u8 {
        if (p9req.len > InlineMax) return error.RequestTooLarge;

        var th = TransportHeader{};
        th.flags = 0;
        th.msg_len = @intCast(p9req.len);

        const hb = std.mem.asBytes(&th);

        var off: usize = 0;
        @memcpy(self.tx[off .. off + hb.len], hb);
        off += hb.len;
        @memcpy(self.tx[off .. off + p9req.len], p9req);
        off += p9req.len;

        if (l49_ipc_send(self.ep, &self.tx[0], off) != 0) return error.TransportSend;

        var out_len: usize = 0;
        if (l49_ipc_recv(self.ep, &self.rx[0], self.rx.len, &out_len) != 0) return error.TransportRecv;
        if (out_len < @sizeOf(TransportHeader)) return error.TransportShort;

        const rth = @as(*const TransportHeader, @ptrCast(@alignCast(&self.rx[0]))).*;
        if (rth.magic != 0x3934504C or rth.version != 0x0001) return error.TransportBad;
        if ((rth.flags & 0x0001) != 0) return error.DataspaceNotSupported;

        const p9_len: usize = @intCast(rth.msg_len);
        const p9_off: usize = @sizeOf(TransportHeader);
        if (p9_off + p9_len > out_len) return error.TransportBadLen;

        return self.rx[p9_off .. p9_off + p9_len];
    }
};

fn checkNoRerror(frame: []const u8) !void {
    const h = try codec.decodeHeader(frame);
    const mt = types.msgTypeFromU8(h.mtype) orelse return error.BadReplyType;
    if (mt == .Rerror) {
        var r = codec.Reader.init(codec.payloadSlice(frame, h));
        const msg = try r.readString();
        _ = msg;
        return error.ServerError;
    }
}

fn expectType(frame: []const u8, want: types.MsgType, want_tag: u16) !void {
    const h = try codec.decodeHeader(frame);
    const mt = types.msgTypeFromU8(h.mtype) orelse return error.BadReplyType;
    if (mt != want) return error.UnexpectedReply;
    if (h.tag != want_tag) return error.BadReplyTag;
}

pub fn run(root_ep: u32) !void {
    log("p9probe: begin\n");

    var tr = Transport{ .ep = root_ep };
    var reqbuf: [InlineMax]u8 = undefined;

    const fid_root: u32 = 1;
    const fid_sys: u32 = 2;
    const fid_ver: u32 = 3;
    const fid_dev: u32 = 4;
    const fid_cons: u32 = 5;

    var tag: u16 = 1;

    {
        log("p9probe: Tversion\n");
        const req = try codec.encodeTversion(&reqbuf, tag, 8192, "9P2000");
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rversion, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Tattach\n");
        const req = try codec.encodeTattach(&reqbuf, tag, fid_root, types.NOFID, "", "");
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rattach, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Twalk root sys\n");
        const req = try codec.encodeTwalk1(&reqbuf, tag, fid_root, fid_sys, "sys");
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rwalk, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Twalk sys version\n");
        const req = try codec.encodeTwalk1(&reqbuf, tag, fid_sys, fid_ver, "version");
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rwalk, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Topen version ro\n");
        const req = try codec.encodeTopen(&reqbuf, tag, fid_ver, @intFromEnum(types.OpenMode.OREAD));
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Ropen, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Tread version\n");
        const req = try codec.encodeTread(&reqbuf, tag, fid_ver, 0, 256);
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rread, tag);

        const h = try codec.decodeHeader(rep);
        var rr = codec.Reader.init(codec.payloadSlice(rep, h));
        const n = try rr.readU32();
        const data = try rr.readBytes(@intCast(n));

        var tmp: [201]u8 = undefined;
        const take = @min(data.len, 200);
        @memcpy(tmp[0..take], data[0..take]);
        tmp[take] = 0;
        l49_puts(@ptrCast(&tmp[0]));
        l49_puts(cstr("\n"));

        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Twalk root dev\n");
        const req = try codec.encodeTwalk1(&reqbuf, tag, fid_root, fid_dev, "dev");
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rwalk, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Twalk dev cons\n");
        const req = try codec.encodeTwalk1(&reqbuf, tag, fid_dev, fid_cons, "cons");
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rwalk, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Topen cons wo\n");
        const req = try codec.encodeTopen(&reqbuf, tag, fid_cons, @intFromEnum(types.OpenMode.OWRITE));
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Ropen, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Twrite cons\n");
        const msg = "hello from p9probe\n";
        const req = try codec.encodeTwrite(&reqbuf, tag, fid_cons, 0, msg);
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rwrite, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Tclunk version\n");
        const req = try codec.encodeTclunk(&reqbuf, tag, fid_ver);
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rclunk, tag);
        tag +%= 1;
        if (tag == 0) tag = 1;
    }

    {
        log("p9probe: Tclunk cons\n");
        const req = try codec.encodeTclunk(&reqbuf, tag, fid_cons);
        const rep = try tr.call(req);
        try checkNoRerror(rep);
        try expectType(rep, .Rclunk, tag);
    }

    log("p9probe: done\n");
}
