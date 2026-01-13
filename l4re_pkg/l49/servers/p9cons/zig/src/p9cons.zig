// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const types = @import("../../../../../src/p9/types.zig");
const codec = @import("../../../../../src/p9/codec.zig");

extern fn l49_puts(s: [*:0]const u8) void;
extern fn l49_ipc_recv(endpoint_cap: u32, buf: *u8, buf_cap: usize, out_len: *usize) c_int;
extern fn l49_ipc_reply(buf: *const u8, buf_len: usize) c_int;

fn cstr(comptime s: []const u8) [*:0]const u8 {
    return s ++ "\x00";
}

pub const InlineMax: usize = 1024;

pub const TransportHeader = packed struct {
    magic: u32 = 0x3934504C, // LP49
    version: u16 = 0x0001,
    flags: u16 = 0,
    msg_len: u32 = 0,
    aux: u32 = 0,
    reserved: u32 = 0,
};

const Node = enum(u8) {
    none,
    root,
    cons,
};

const FidEntry = struct {
    used: bool = false,
    fid: u32 = 0,
    node: Node = .none,
    open: bool = false,
};

pub const P9Cons = struct {
    ep: u32,

    rx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,
    tx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,
    p9_tx: [InlineMax]u8 = undefined,

    fids: [32]FidEntry = .{.{}} ** 32,

    pub fn init(ep: u32) P9Cons {
        return .{ .ep = ep };
    }

    fn log(comptime s: []const u8) void {
        l49_puts(cstr(s));
    }

    fn replyInline(self: *P9Cons, p9: []const u8) void {
        var hdr = TransportHeader{};
        hdr.flags = 0;
        hdr.msg_len = @intCast(p9.len);

        const hb = std.mem.asBytes(&hdr);

        var off: usize = 0;
        @memcpy(self.tx[off .. off + hb.len], hb);
        off += hb.len;
        @memcpy(self.tx[off .. off + p9.len], p9);
        off += p9.len;

        _ = l49_ipc_reply(&self.tx[0], off);
    }

    fn fidFind(self: *P9Cons, fid: u32) ?*FidEntry {
        for (&self.fids) |*e| {
            if (e.used and e.fid == fid) return e;
        }
        return null;
    }

    fn fidAlloc(self: *P9Cons, fid: u32, node: Node) *FidEntry {
        if (self.fidFind(fid)) |e| {
            e.node = node;
            e.open = false;
            return e;
        }
        for (&self.fids) |*e| {
            if (!e.used) {
                e.used = true;
                e.fid = fid;
                e.node = node;
                e.open = false;
                return e;
            }
        }
        self.fids[0] = .{ .used = true, .fid = fid, .node = node, .open = false };
        return &self.fids[0];
    }

    fn fidFree(self: *P9Cons, fid: u32) void {
        if (self.fidFind(fid)) |e| e.* = .{};
    }

    fn qidFor(node: Node) types.Qid {
        return switch (node) {
            .root => .{ .qtype = 0x80, .vers = 0, .path = 1 },
            .cons => .{ .qtype = 0x00, .vers = 0, .path = 2 },
            else => .{ .qtype = 0x00, .vers = 0, .path = 0 },
        };
    }

    pub fn run(self: *P9Cons) !void {
        log("p9cons: run\n");

        while (true) {
            var n: usize = 0;
            if (l49_ipc_recv(0, &self.rx[0], self.rx.len, &n) != 0) {
                log("p9cons: recv failed\n");
                continue;
            }
            if (n < @sizeOf(TransportHeader)) continue;

            const th = @as(*const TransportHeader, @ptrCast(@alignCast(&self.rx[0]))).*;
            if (th.magic != 0x3934504C or th.version != 0x0001) continue;
            if ((th.flags & 0x0001) != 0) continue;

            const p9_len: usize = @intCast(th.msg_len);
            const p9_off: usize = @sizeOf(TransportHeader);
            if (p9_off + p9_len > n or p9_len > InlineMax) continue;

            const frame = self.rx[p9_off .. p9_off + p9_len];

            const hdr = codec.decodeHeader(frame) catch {
                const rep = codec.encodeRerror(&self.p9_tx, 0, "bad header") catch &[_]u8{};
                self.replyInline(rep);
                continue;
            };

            const mt = types.msgTypeFromU8(hdr.mtype) orelse {
                const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad type") catch &[_]u8{};
                self.replyInline(rep);
                continue;
            };

            switch (mt) {
                .Tversion => {
                    const req = codec.decodeTversion(frame) catch {
                        const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad tversion") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    const rep = codec.encodeRversion(&self.p9_tx, req.tag, req.msize, req.version) catch {
                        const er = codec.encodeRerror(&self.p9_tx, req.tag, "encode rversion") catch &[_]u8{};
                        self.replyInline(er);
                        continue;
                    };
                    self.replyInline(rep);
                },

                .Tattach => {
                    const req = codec.decodeTattach(frame) catch {
                        const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad tattach") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    _ = self.fidAlloc(req.fid, .root);
                    const rep = codec.encodeRattach(&self.p9_tx, req.tag, qidFor(.root)) catch {
                        const er = codec.encodeRerror(&self.p9_tx, req.tag, "encode rattach") catch &[_]u8{};
                        self.replyInline(er);
                        continue;
                    };
                    self.replyInline(rep);
                },

                .Twalk => {
                    const req = codec.decodeTwalk(frame) catch {
                        const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad twalk") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };

                    const from = self.fidFind(req.fid) orelse {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "unknown fid") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };

                    if (req.nwname == 0) {
                        _ = self.fidAlloc(req.newfid, from.node);
                        const rep = codec.encodeRwalk0(&self.p9_tx, req.tag) catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    }

                    if (from.node != .root or req.nwname != 1) {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "walk unsupported") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    }

                    const name = req.wname[0];
                    if (std.mem.eql(u8, name, "cons")) {
                        _ = self.fidAlloc(req.newfid, .cons);
                        const rep = codec.encodeRwalk1(&self.p9_tx, req.tag, qidFor(.cons)) catch &[_]u8{};
                        self.replyInline(rep);
                    } else {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "not found") catch &[_]u8{};
                        self.replyInline(rep);
                    }
                },

                .Topen => {
                    const req = codec.decodeTopen(frame) catch {
                        const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad topen") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    const e = self.fidFind(req.fid) orelse {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "unknown fid") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    e.open = true;

                    const rep = codec.encodeRopen(&self.p9_tx, req.tag, qidFor(e.node), 0) catch {
                        const er = codec.encodeRerror(&self.p9_tx, req.tag, "encode ropen") catch &[_]u8{};
                        self.replyInline(er);
                        continue;
                    };
                    self.replyInline(rep);
                },

                .Tread => {
                    const rep = codec.encodeRread(&self.p9_tx, hdr.tag, "") catch &[_]u8{};
                    self.replyInline(rep);
                },

                .Twrite => {
                    const req = codec.decodeTwrite(frame) catch {
                        const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad twrite") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    const e = self.fidFind(req.fid) orelse {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "unknown fid") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    if (e.node != .cons) {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "write denied") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    }

                    var tmp: [256]u8 = undefined;
                    const ncopy = @min(req.data.len, tmp.len - 1);
                    @memcpy(tmp[0..ncopy], req.data[0..ncopy]);
                    tmp[ncopy] = 0;
                    l49_puts(@ptrCast(&tmp[0]));

                    const rep = codec.encodeRwrite(&self.p9_tx, req.tag, @intCast(req.data.len)) catch &[_]u8{};
                    self.replyInline(rep);
                },

                .Tclunk => {
                    const req = codec.decodeTclunk(frame) catch {
                        const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad tclunk") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    self.fidFree(req.fid);
                    const rep = codec.encodeRclunk(&self.p9_tx, req.tag) catch &[_]u8{};
                    self.replyInline(rep);
                },

                else => {
                    const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "unsupported") catch &[_]u8{};
                    self.replyInline(rep);
                },
            }
        }
    }
};
