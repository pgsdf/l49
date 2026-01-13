// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const P9Root = @import("p9root.zig").P9Root;

extern fn l49_puts(s: [*:0]const u8) void;
extern fn l49_get_cap(name: [*:0]const u8) u32;

fn cstr(comptime s: []const u8) [*:0]const u8 {
    return s ++ "\x00";
}

pub export fn main() void {
    const ep = l49_get_cap(cstr("ep"));
    if (ep == 0) {
        l49_puts(cstr("p9root: missing cap 'ep'\n"));
        return;
    }
    const cons_ep = l49_get_cap(cstr("cons_ep"));

    var srv = P9Root.init(ep, cons_ep);
    srv.run() catch {
        l49_puts(cstr("p9root: fatal\n"));
    };
}
