# 13. Coding Standards

Yuki style is inspired by TigerStyle and pointer-light Zig, but adapted for a game engine.

The runtime core should be strict. Tools and Studio can be more pragmatic.

## Runtime Zig rules

- Prefer handles, indices, and IDs over long-lived pointer graphs.
- Make ownership explicit.
- Avoid hidden allocations in hot paths.
- Use bounded buffers and explicit limits where possible.
- Keep data layouts cache-friendly.
- Separate control-plane code from frame-critical data-plane code.
- Use assertions for programmer invariants.
- Use errors for expected runtime failures.
- Keep APIs small and boring.

## Luau rules

- Prefer `--!strict`.
- Avoid accidental globals.
- Use generated type definitions.
- Keep scripts high-level.
- Batch calls into Zig where possible.
- Store large/authoritative state in Zig systems, not random Luau table graphs.

## Module rules

- Modules should own one clear domain.
- Modules should expose simple Luau APIs.
- Modules should validate content before runtime when possible.
- Modules should not force Studio to exist.

## Docs rules

- Write for humans first.
- Keep docs short unless detail is necessary.
- Prefer examples over abstract explanations.
- Mark uncertain or future work clearly.
