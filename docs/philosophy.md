# Philosophy

## Scope
This document explains why L49 exists.
It does not define implementation details.

## Motivation
Many systems expose a large and evolving system call surface.
L49 exposes one semantic interface: 9P.

The kernel enforces isolation and scheduling.
User space defines meaning.

## Zig
Zig is used for explicit memory management and predictable binaries.
Userland services should be readable and boring.
