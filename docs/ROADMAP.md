# L49 roadmap

## Scope
This roadmap is intentionally small.
Only milestones that are planned or partially implemented are listed.
Ideas belong in issues, not here.

## Milestone 1 boot to 9P namespace

Goals
- Boot on x86_64 under QEMU using Fiasco.OC and L4Re
- Expose a minimal Plan 9 style namespace through 9P
- Implement userland services in Zig with a tiny C shim for L4Re

Success criteria
- p9probe completes a fixed 9P sequence
- sys version returns a non empty string
- dev cons prints to the console
- No heap allocation in the 9P transport path

Non goals
- No persistence
- No networking
- No directory listing
- No authentication
- No POSIX compatibility

## Milestone 2 namespace expansion

Planned features
- Directory reads
- Stat support
- Multiple walk elements
- Dataspace backed large reads and writes
- Better fid lifetime enforcement

Deferred
- Remote 9P
- Persistent storage
- Compatibility layers
