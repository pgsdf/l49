// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");
const P9Cons = @import("p9cons.zig").P9Cons;

extern fn l49_puts(s: [*:0]const u8) void;
extern fn l49_get_cap(name: [*:0]const u8) u32;

fn cstr(comptime s: []const u8) [*:0]const u8 {
    return s ++ "\x00";
}

pub export fn main() void {
    const ep = l49_get_cap(cstr("ep"));
    if (ep == 0) {
        l49_puts(cstr("p9cons: missing cap 'ep'\n"));
        return;
    }

    var srv = P9Cons.init(ep);
    srv.run() catch {
        l49_puts(cstr("p9cons: fatal\n"));
    };
}
