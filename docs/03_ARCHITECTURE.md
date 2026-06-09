# 03. Architecture

Yuki has two main layers:

- **Zig runtime**: engine, renderer, assets, modules, tooling.
- **Luau game layer**: user scripts, gameplay logic, content definitions, UI controllers.

## High-level stack

```text
Yuki Studio                  future native editor built with Yuki
Luau SDK                     public game API
Game standard library         saves, inventory, dialogue, maps, UI, etc.
Yuki2D / future Yuki3D        rendering and game runtime layers
Yuki core                     app, world, assets, events, content, Luau host
Backends                      SDL3 platform + wgpu-native graphics
Third-party libraries         Luau, SDL3, wgpu-native, optional importers
```

## Core responsibility

The core owns mechanisms:

- app lifecycle;
- logging;
- time;
- filesystem/virtual filesystem;
- assets;
- content registry;
- event bus;
- world/entity storage;
- Luau VM hosting;
- native module registration;
- build/package hooks.

The core should not own game concepts such as inventory, dialogue, quests, crafting, or combat rules.

## Module responsibility

Modules own game-facing systems:

- inventory;
- dialogue;
- saves;
- animation;
- tilemaps;
- localization;
- UI;
- future AI/combat/quest systems.

A module can expose:

- Zig runtime code;
- Luau API;
- content schema;
- save integration;
- Studio metadata later.

## Runtime flow

```text
start app
  load config
  init SDL3
  init wgpu-native
  init Yuki core
  load modules
  init Luau VM
  load compiled scripts/assets
  run update/render loop
```

## Data flow

```text
Luau source / structured content
  -> validation
  -> content IDs and packs
  -> runtime handles
  -> Luau API uses handles, not raw pointers
```

Development should keep data easy to edit. Release builds should compile Luau to bytecode and pack assets/content.

## Design bias

Yuki should prefer:

- handles over long-lived pointers;
- explicit ownership;
- bounded systems;
- batched Lua-to-Zig calls;
- small core APIs;
- engine-level concepts over raw backend exposure.
