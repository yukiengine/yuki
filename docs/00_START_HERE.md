# 00. Start Here

These docs are working notes for Yuki Engine. They are meant to guide development, not freeze every decision.

Yuki is currently in the design/planning stage. The project should stay flexible while the first runtime is being built.

## What Yuki wants to be

A code-first game engine with:

- a strong 2D foundation first;
- Zig-powered native systems;
- Luau as the main game scripting language;
- a reusable game standard library;
- a future native editor built with Yuki itself.

## What to read first

1. **Vision** — what the engine is trying to become.
2. **Roadmap** — current build order.
3. **Architecture** — how the major pieces fit together.
4. **API Shape** — what the engine should expose.
5. **Yuki2D** — the first real product target.

## How to treat these docs

- Treat them as direction, not law.
- Prefer small working milestones over perfect architecture.
- Keep the runtime code-first until the engine can justify a native editor.
- Avoid adding systems before they are needed by a real demo.
