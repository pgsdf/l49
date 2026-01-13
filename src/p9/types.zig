// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Pacific Grove Software Distribution Foundation

const std = @import("std");

pub const NOFID: u32 = 0xFFFF_FFFF;

pub const MsgType = enum(u8) {
    Tversion = 100,
    Rversion = 101,

    Tattach = 104,
    Rattach = 105,

    Rerror = 107,

    Twalk = 110,
    Rwalk = 111,

    Topen = 112,
    Ropen = 113,

    Tread = 116,
    Rread = 117,

    Twrite = 118,
    Rwrite = 119,

    Tclunk = 120,
    Rclunk = 121,
};

pub const Qid = packed struct {
    qtype: u8,
    vers: u32,
    path: u64,
};

pub const Header = packed struct {
    size: u32,
    mtype: u8,
    tag: u16,
};

pub const OpenMode = enum(u8) {
    OREAD = 0,
    OWRITE = 1,
    ORDWR = 2,
    OEXEC = 3,
};

pub const WalkMax = 16;

pub const DecodeError = error{
    Short,
    BadSize,
    BadType,
    BadString,
};

pub const EncodeError = error{
    NoSpace,
    StringTooLong,
};

pub fn msgTypeFromU8(v: u8) ?MsgType {
    return std.meta.intToEnum(MsgType, v) catch null;
}
