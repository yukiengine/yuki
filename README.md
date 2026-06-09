# Yuki Engine

Yuki Engine is an experimental game engine project.

The goal is to build a code-first engine with a strong 2D foundation, a useful game standard library, and eventually a native editor built with the engine itself.

The current technical direction is:

- **Zig** for the engine core, tools, native modules, and low-level systems.
- **Luau** as the default user-facing game scripting language.
- **SDL3** for platform services: windows, input, controllers, audio devices, lifecycle.
- **wgpu-native** for graphics.
- **Yuki Studio** later as a native app built with Yuki, not a web-first editor.

Yuki is not trying to be Unity, Godot, Unreal, or Raylib. It is trying to become a practical middle ground: code-first like a library, but with enough built-in game systems to avoid rewriting the same boilerplate for every project.

## Current status

Planning and early architecture.

No engine code should be treated as stable yet. These docs describe the intended shape of the project so development can start with a clear direction.

## Near-term focus

The first real target is **Yuki2D**: a polished 2D runtime/library that can run simple games from Luau scripts.

Initial tasks:

1. Create the Zig project skeleton.
2. Set up SDL3 window/input/audio lifecycle.
3. Set up wgpu-native device/surface rendering.
4. Host Luau and run a script update loop.
5. Draw textured sprites.
6. Package a small game with compiled Luau bytecode and assets.

## Reading order

Start here:

1. [docs/00_START_HERE.md](docs/00_START_HERE.md)
2. [docs/01_VISION.md](docs/01_VISION.md)
3. [docs/02_ROADMAP.md](docs/02_ROADMAP.md)
4. [docs/03_ARCHITECTURE.md](docs/03_ARCHITECTURE.md)

Then read the topic-specific docs as needed.

## License

MIT.
