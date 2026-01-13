// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");

fn addObj(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, name: []const u8, src: []const u8) void {
    const obj = b.addObject(.{
        .name = name,
        .root_source_file = b.path(src),
        .target = target,
        .optimize = optimize,
    });
    _ = b.addInstallArtifact(obj, .{});
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const emit_obj = b.option(bool, "emit-obj", "Emit object files for BID linking") orelse false;

    if (emit_obj) {
        addObj(b, target, optimize, "p9root_main", "src/main.zig");
        addObj(b, target, optimize, "p9root", "src/p9root.zig");
        addObj(b, target, optimize, "p9_codec", "../../../../../src/p9/codec.zig");
    } else {
        const step = b.step("help", "Use -Demit-obj=true to build L4Re objects");
        _ = step;
    }
}
