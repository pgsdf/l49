# Contributing

Thank you for helping improve L49.

## Scope and priorities

L49 is milestone driven.
Contributions should reduce ambiguity, improve correctness, or make the system easier to understand and reproduce.

Before proposing new features, confirm they fit the current milestone.
If a change expands scope, open an issue first and describe the motivation and the smallest acceptable outcome.

## Principles

- Prefer small changes over large rewrites
- Prefer explicit interfaces over implicit behavior
- Keep the kernel policy free, keep meaning in user space
- Keep the build deterministic and the toolchain pinned
- Keep documentation current with code

## Workflow

1. Open an issue describing the change and the expected behavior.
2. Create a branch with a clear name.
3. Make one focused change per pull request.
4. Add or update tests when behavior changes.
5. Update documentation when interfaces or assumptions change.

## Style

- Avoid cleverness
- Keep error messages actionable
- Do not introduce global registries or hidden side channels
- Keep logs readable and minimal

## Toolchain

Zig 0.15.2 is required.
If a toolchain upgrade is proposed, it must be a separate change with a clear migration note.
