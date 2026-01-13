# Architecture

## Scope
Milestone 1 only.

## Summary
L49 is a Plan 9 personality on an L4 microkernel.

Kernel
Fiasco.OC provides threads, address spaces, scheduling, IPC, and capability enforcement.

Runtime
L4Re bootstraps tasks and provides basic runtime services.

Userland
All operating system services are user space servers written in Zig.
The system interface is 9P.
Local 9P messages are carried over L4 IPC.

## Server graph for Milestone 1
cons
Standard L4Re console server used for system logging.

p9cons
A 9P server that exposes a single file: cons.
Writes print to the console.

p9root
A 9P server that exposes:
dev cons
sys version

p9probe
A client that proves the system by running a fixed 9P sequence.

## Transport model
The kernel does not understand 9P.
Servers decode 9P in user space.
Replies are sent using the implicit reply capability returned by IPC wait.

Large payload support using dataspaces is defined but not required for Milestone 1.
