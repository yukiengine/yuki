# 10. Build and Packaging

Yuki has three build worlds:

1. engine/tool development;
2. game development;
3. release packaging.

## Engine development

Builds the engine libraries and tools:

```text
yuki-cli
Yuki runtime
SDL3 integration
wgpu-native integration
Luau host
```

## Game development

`yuki dev` should eventually:

- build native code when needed;
- run the game;
- load loose Luau files;
- hot reload scripts/assets where practical;
- show validation errors.

## Release packaging

`yuki package` should eventually:

- compile Zig runtime and selected modules;
- statically link dependencies where practical;
- compile Luau to bytecode;
- pack assets and content;
- exclude raw Luau source by default;
- emit a game executable and `game.pak` or an embedded equivalent.

Default release target:

```text
TinyQuest
  TinyQuest executable
  game.pak
```

The project prefers static linking from the start. If a platform or dependency makes static linking impractical during early development, the fallback must be explicit and documented.

## Engine as library or binary

Yuki is both:

- a set of libraries/packages used by games;
- CLI tools that build, check, and package projects;
- later, a native Studio application.

The final game is its own executable. It contains or links the Yuki runtime.
