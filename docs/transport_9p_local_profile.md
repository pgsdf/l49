# Local 9P transport profile

## Purpose
This document defines the local 9P transport used inside L49 for Milestone 1.

The semantic protocol is 9P.
The transport is L4 IPC.
Large payloads may later use L4Re dataspaces.

## Message framing
One 9P message per request and one per reply.

Inline mode
- Full 9P bytes carried in the IPC payload

Dataspace mode
- Not used in Milestone 1
- Defined for later milestones

## Inline threshold
INLINE_MAX is 1024 bytes for Milestone 1.

## Transport header
All fields are little endian.

magic
0x3934504C ASCII LP49

version
0x0001

flags bit 0
1 means dataspace mode

msg_len
Length of the 9P message bytes
