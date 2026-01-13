# L49

L49 is a Plan 9 personality built on an L4 microkernel.

The kernel provides isolation, scheduling, and IPC.
User space provides meaning.
The primary semantic interface is 9P.

This repository is designed to be small, explicit, and practical.
Milestones are chosen to prove behavior, not to accumulate features.

## Status

Milestone 1 is implemented and documented.
It boots on x86_64 under QEMU with Fiasco.OC and L4Re and proves a minimal 9P namespace end to end.

## What you can do today

- Read sys version via 9P
- Write to dev cons via 9P and see output on the console
- Trace every request and reply through a single user space path

## Design constraints

- Zig version is pinned to 0.15.2
- All Plan 9 userland services are written in Zig
- A tiny C shim is used only for L4Re IPC and environment access
- No heap allocation in the 9P transport path for Milestone 1
- No global capability registry, capabilities are passed explicitly by the scenario

## Repository layout

docs
Design documentation and runbook

src
Core 9P types and codec

l4re_pkg
L4Re package containing servers, scenario, and shim

tests
Host side unit tests for protocol encoding and decoding

scripts
Small helper scripts, including toolchain checks

## Build and run

See docs build_and_run.md.

## Contributing

See CONTRIBUTING.md.

## License

MIT License, see LICENSE.
