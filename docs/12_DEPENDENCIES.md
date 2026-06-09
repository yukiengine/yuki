# 12. Dependencies

Dependencies should be wrapped behind Yuki APIs. User Luau code should not depend on third-party library shapes.

## Core dependencies

| Dependency | Use |
|---|---|
| Zig | engine, tools, native modules |
| SDL3 | platform, window, input, controllers, audio device |
| wgpu-native | graphics backend |
| Luau | scripting language and bytecode VM |

## Early optional dependencies

| Dependency | Use |
|---|---|
| SDL_image | development image loading/import |
| SDL_ttf | early text/font path |
| Box2D | future 2D physics module |

## Later 3D dependencies

| Dependency | Use |
|---|---|
| cgltf | glTF import |
| meshoptimizer | mesh optimization |
| Basis Universal / KTX2 tooling | texture compression pipeline |
| Jolt Physics | future 3D physics |

## Tooling dependencies

| Dependency | Use |
|---|---|
| luau-analyze | script type checking/linting |
| StyLua | optional Luau formatting |
| Nix | reproducible dev shell |

## Policy

- Pin versions.
- Wrap dependencies.
- Keep dependency upgrades intentional.
- Do not expose dependency APIs directly to Luau.
- Prefer small focused dependencies over large frameworks.
- Keep optional dependencies optional until a milestone needs them.
