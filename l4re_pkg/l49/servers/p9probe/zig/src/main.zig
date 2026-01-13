// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const probe = @import("p9probe.zig");

extern fn l49_puts(s: [*:0]const u8) void;
extern fn l49_get_cap(name: [*:0]const u8) u32;

fn cstr(comptime s: []const u8) [*:0]const u8 {
    return s ++ "\x00";
}

pub export fn main() void {
    const root_ep = l49_get_cap(cstr("root_ep"));
    if (root_ep == 0) {
        l49_puts(cstr("p9probe: missing cap 'root_ep'\n"));
        return;
    }

    probe.run(root_ep) catch {
        l49_puts(cstr("p9probe: fatal\n"));
    };
}
