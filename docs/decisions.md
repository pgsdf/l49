# Decisions

## Zig version
Zig 0.15.2 is required.

## Userland language
All Plan 9 personality services are written in Zig.
The only non Zig code is a tiny C shim that wraps L4Re IPC and environment functions.

## 9P dialect
Milestone 1 implements a minimal subset of 9P2000 message types.

## Transport
9P is semantics.
L4 IPC is transport only.
A small local transport header frames one 9P message per exchange.

## Allocation policy
Milestone 1 avoids heap allocation in transport paths.
Fid tables are fixed size.
Buffers are fixed size.
