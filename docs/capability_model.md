# Capability model

## Scope
Milestone 1.

## Principle
No global capability registry.
All communication capabilities are passed explicitly at task start.

## Channels
cons
Used for system logging only.

cons9p
p9cons server endpoint.
p9root client endpoint.

root9p
p9root server endpoint.
p9probe client endpoint.

## Trust boundaries
p9probe is untrusted relative to p9root.
p9root is untrusted relative to the kernel.
