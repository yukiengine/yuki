# AGENTS.md

This file describes how AI agents should help with Yuki Engine.

Yuki is owned and directed by the project maintainer. Agents assist; they do not steer the project by inventing large new directions without being asked.

## First steps for agents

Read these files before making broad changes:

1. `README.md`
2. `docs/00_START_HERE.md`
3. `docs/01_VISION.md`
4. `docs/02_ROADMAP.md`
5. `docs/13_CODING_STANDARDS.md`

## What agents should do

Agents may help with:

- explaining concepts;
- researching dependencies and tradeoffs;
- drafting or tightening docs;
- proposing project structure;
- writing small isolated code changes;
- refactoring when requested;
- keeping docs consistent with decisions.

## What agents should avoid

Do not:

- make the docs verbose just to be comprehensive;
- repeat the same idea across many files;
- present future ideas as already-decided facts;
- introduce new dependencies without explaining why;
- expose SDL or wgpu-native directly to Luau APIs;
- turn early Yuki into a web-first editor project;
- overbuild before the current milestone needs it.

## Current direction

- Zig core.
- Luau user scripting.
- SDL3 platform layer.
- wgpu-native graphics layer.
- Yuki2D first.
- Game standard library second.
- Yuki UI runtime and native Yuki Studio later.
- 3D after the 2D/runtime foundation is solid.

## Style expectations

Docs should be human-first:

- concise;
- numbered where useful;
- clear about current status;
- clear about what is planned versus optional;
- easy to scan.

Code should follow `docs/13_CODING_STANDARDS.md`.

## Research expectations

When researching current tools, dependencies, APIs, or versions, use up-to-date sources and cite them in the response. Do not rely on stale memory for fast-moving dependencies.
