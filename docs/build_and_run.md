# Build and run

## Scope
Milestone 1 on x86_64 QEMU using Fiasco.OC and L4Re.

## Requirements
- Zig 0.15.2
- L4Re and Fiasco.OC checkout
- QEMU for x86_64

## Quick steps
1. Verify zig version is 0.15.2
2. Link l4re_pkg/l49 into your L4Re tree at pkg/l49
3. Build p9cons, p9root, and p9probe via the L4Re build system
4. Run QEMU with the scenario cfg l49.cfg

Expected output includes:
L49 milestone1
hello from p9probe

See debugging.md if output differs.
