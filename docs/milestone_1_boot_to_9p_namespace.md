# Milestone 1 boot to 9P namespace

## Goal
Boot on x86_64 QEMU and prove that the user visible system interface is 9P.

## Non goals
- No POSIX compatibility
- No network transport
- No persistence
- No directory listing
- No authentication

## Success criteria
1. QEMU boots an L4Re scenario that starts p9cons, p9root, and p9probe.
2. p9probe performs:
Tversion
Tattach
Twalk sys
Twalk version
Topen
Tread
Twalk dev
Twalk cons
Topen
Twrite
Tclunk
3. The version string is printed by p9probe.
4. The message hello from p9probe is printed via dev cons.

See debugging.md for failure mode guidance.
