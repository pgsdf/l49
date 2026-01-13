// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const types = @import("../../../../../src/p9/types.zig");
const codec = @import("../../../../../src/p9/codec.zig");

extern fn l49_puts(s: [*:0]const u8) void;
extern fn l49_ipc_recv(endpoint_cap: u32, buf: *u8, buf_cap: usize, out_len: *usize) c_int;
extern fn l49_ipc_reply(buf: *const u8, buf_len: usize) c_int;
extern fn l49_ipc_call(ep_cap: u32, req: *const u8, req_len: usize, rep: *u8, rep_cap: usize, out_len: *usize) c_int;

fn cstr(comptime s: []const u8) [*:0]const u8 {
    return s ++ "\x00";
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

const Node = enum(u8) {
    none,
    root,
    dev,
    sys,
    cons,
    version,
};

const FidEntry = struct {
    used: bool = false,
    fid: u32 = 0,
    node: Node = .none,
    open: bool = false,
};

const ConsClient = struct {
    ep: u32,
    tag_next: u16 = 1,
    fid_root: u32 = 1,
    fid_cons: u32 = 2,
    cons_ready: bool = false,

    tx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,
    rx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,
    p9tx: [InlineMax]u8 = undefined,

    fn log(comptime s: []const u8) void {
        l49_puts(cstr(s));
    }

    fn nextTag(self: *ConsClient) u16 {
        const t = self.tag_next;
        self.tag_next +%= 1;
        if (self.tag_next == 0) self.tag_next = 1;
        return t;
    }

    fn call(self: *ConsClient, p9req: []const u8) ![]const u8 {
        if (self.ep == 0) return error.NoEndpoint;
        if (p9req.len > InlineMax) return error.TooLarge;

        var th = TransportHeader{};
        th.flags = 0;
        th.msg_len = @intCast(p9req.len);

        const hb = std.mem.asBytes(&th);

        var off: usize = 0;
        @memcpy(self.tx[off .. off + hb.len], hb);
        off += hb.len;
        @memcpy(self.tx[off .. off + p9req.len], p9req);
        off += p9req.len;

        var out_len: usize = 0;
        if (l49_ipc_call(self.ep, &self.tx[0], off, &self.rx[0], self.rx.len, &out_len) != 0)
            return error.Transport;

        if (out_len < @sizeOf(TransportHeader)) return error.Short;
        const rth = @as(*const TransportHeader, @ptrCast(@alignCast(&self.rx[0]))).*;
        if (rth.magic != 0x3934504C or rth.version != 0x0001) return error.BadTransport;
        if ((rth.flags & 0x0001) != 0) return error.DataspaceNotSupported;

        const p9_len: usize = @intCast(rth.msg_len);
        const p9_off: usize = @sizeOf(TransportHeader);
        if (p9_off + p9_len > out_len) return error.BadLen;

        return self.rx[p9_off .. p9_off + p9_len];
    }

    fn ensureReady(self: *ConsClient) void {
        if (self.ep == 0 or self.cons_ready) return;

        {
            const tag = self.nextTag();
            const req = codec.encodeTversion(&self.p9tx, tag, 8192, "9P2000") catch {
                log("p9root: cons encode tversion failed\n");
                return;
            };
            _ = self.call(req) catch {
                log("p9root: cons tversion failed\n");
                return;
            };
        }

        {
            const tag = self.nextTag();
            const req = codec.encodeTattach(&self.p9tx, tag, self.fid_root, types.NOFID, "", "") catch {
                log("p9root: cons encode tattach failed\n");
                return;
            };
            _ = self.call(req) catch {
                log("p9root: cons tattach failed\n");
                return;
            };
        }

        {
            const tag = self.nextTag();
            const req = codec.encodeTwalk1(&self.p9tx, tag, self.fid_root, self.fid_cons, "cons") catch {
                log("p9root: cons encode twalk failed\n");
                return;
            };
            _ = self.call(req) catch {
                log("p9root: cons twalk failed\n");
                return;
            };
        }

        {
            const tag = self.nextTag();
            const req = codec.encodeTopen(&self.p9tx, tag, self.fid_cons, @intFromEnum(types.OpenMode.OWRITE)) catch {
                log("p9root: cons encode topen failed\n");
                return;
            };
            _ = self.call(req) catch {
                log("p9root: cons topen failed\n");
                return;
            };
        }

        self.cons_ready = true;
        log("p9root: cons ready\n");
    }

    fn write(self: *ConsClient, data: []const u8) void {
        if (self.ep == 0) return;
        self.ensureReady();
        if (!self.cons_ready) return;

        const tag = self.nextTag();
        const req = codec.encodeTwrite(&self.p9tx, tag, self.fid_cons, 0, data) catch return;
        _ = self.call(req) catch return;
    }
};

pub const P9Root = struct {
    ep: u32,
    cons: ConsClient,

    rx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,
    tx: [InlineMax + @sizeOf(TransportHeader)]u8 = undefined,
    p9_tx: [InlineMax]u8 = undefined,

    fids: [64]FidEntry = .{.{}} ** 64,

    pub fn init(ep: u32, cons_ep: u32) P9Root {
        return .{ .ep = ep, .cons = .{ .ep = cons_ep } };
    }

    fn log(comptime s: []const u8) void {
        l49_puts(cstr(s));
    }

    fn replyInline(self: *P9Root, p9: []const u8) void {
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

    fn fidFind(self: *P9Root, fid: u32) ?*FidEntry {
        for (&self.fids) |*e| {
            if (e.used and e.fid == fid) return e;
        }
        return null;
    }

    fn fidAlloc(self: *P9Root, fid: u32, node: Node) *FidEntry {
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

    fn fidFree(self: *P9Root, fid: u32) void {
        if (self.fidFind(fid)) |e| e.* = .{};
    }

    fn qidFor(node: Node) types.Qid {
        return switch (node) {
            .root => .{ .qtype = 0x80, .vers = 0, .path = 1 },
            .dev => .{ .qtype = 0x80, .vers = 0, .path = 2 },
            .sys => .{ .qtype = 0x80, .vers = 0, .path = 3 },
            .cons => .{ .qtype = 0x00, .vers = 0, .path = 4 },
            .version => .{ .qtype = 0x00, .vers = 0, .path = 5 },
            else => .{ .qtype = 0x00, .vers = 0, .path = 0 },
        };
    }

    fn walk1(from: Node, name: []const u8) ?Node {
        return switch (from) {
            .root => blk: {
                if (std.mem.eql(u8, name, "dev")) break :blk .dev;
                if (std.mem.eql(u8, name, "sys")) break :blk .sys;
                break :blk null;
            },
            .dev => blk: {
                if (std.mem.eql(u8, name, "cons")) break :blk .cons;
                break :blk null;
            },
            .sys => blk: {
                if (std.mem.eql(u8, name, "version")) break :blk .version;
                break :blk null;
            },
            else => null,
        };
    }

    fn versionString() []const u8 {
        return "L49 milestone1\n";
    }

    pub fn run(self: *P9Root) !void {
        log("p9root: run\n");

        while (true) {
            var n: usize = 0;
            if (l49_ipc_recv(0, &self.rx[0], self.rx.len, &n) != 0) {
                log("p9root: recv failed\n");
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

                    if (req.nwname != 1) {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "walk multi unsupported") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    }

                    const next = walk1(from.node, req.wname[0]) orelse {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "not found") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };

                    _ = self.fidAlloc(req.newfid, next);
                    const rep = codec.encodeRwalk1(&self.p9_tx, req.tag, qidFor(next)) catch {
                        const er = codec.encodeRerror(&self.p9_tx, req.tag, "encode rwalk") catch &[_]u8{};
                        self.replyInline(er);
                        continue;
                    };
                    self.replyInline(rep);
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
                    const req = codec.decodeTread(frame) catch {
                        const rep = codec.encodeRerror(&self.p9_tx, hdr.tag, "bad tread") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };
                    const e = self.fidFind(req.fid) orelse {
                        const rep = codec.encodeRerror(&self.p9_tx, req.tag, "unknown fid") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    };

                    if (e.node != .version) {
                        const rep = codec.encodeRread(&self.p9_tx, req.tag, "") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    }

                    const v = versionString();
                    const off: usize = @intCast(req.offset);
                    if (off >= v.len) {
                        const rep = codec.encodeRread(&self.p9_tx, req.tag, "") catch &[_]u8{};
                        self.replyInline(rep);
                        continue;
                    }
                    const take = @min(@as(usize, @intCast(req.count)), v.len - off);
                    const rep = codec.encodeRread(&self.p9_tx, req.tag, v[off .. off + take]) catch &[_]u8{};
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

                    self.cons.write(req.data);

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
