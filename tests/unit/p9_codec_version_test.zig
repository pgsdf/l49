// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const types = @import("../../src/p9/types.zig");
const codec = @import("../../src/p9/codec.zig");

test "encode Tversion then decode Tversion yields same msize and version string" {
    var buf: [1024]u8 = undefined;
    const tag: u16 = 7;
    const msize: u32 = 8192;
    const ver = "9P2000";

    const frame = try codec.encodeTversion(&buf, tag, msize, ver);

    const h = try codec.decodeHeader(frame);
    try std.testing.expectEqual(tag, h.tag);
    try std.testing.expectEqual(@intFromEnum(types.MsgType.Tversion), h.mtype);

    const req = try codec.decodeTversion(frame);
    try std.testing.expectEqual(tag, req.tag);
    try std.testing.expectEqual(msize, req.msize);
    try std.testing.expect(std.mem.eql(u8, req.version, ver));
}
