// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const types = @import("../../src/p9/types.zig");
const codec = @import("../../src/p9/codec.zig");

test "encode Twalk1 then decode Twalk yields same fid newfid and name" {
    var buf: [1024]u8 = undefined;
    const tag: u16 = 42;
    const fid: u32 = 1;
    const newfid: u32 = 2;
    const name = "sys";

    const frame = try codec.encodeTwalk1(&buf, tag, fid, newfid, name);

    const h = try codec.decodeHeader(frame);
    try std.testing.expectEqual(tag, h.tag);
    try std.testing.expectEqual(@intFromEnum(types.MsgType.Twalk), h.mtype);

    const req = try codec.decodeTwalk(frame);
    try std.testing.expectEqual(tag, req.tag);
    try std.testing.expectEqual(fid, req.fid);
    try std.testing.expectEqual(newfid, req.newfid);
    try std.testing.expectEqual(@as(u16, 1), req.nwname);
    try std.testing.expect(std.mem.eql(u8, req.wname[0], name));
}
