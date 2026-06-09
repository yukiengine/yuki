# 05. Project Structure

Start as a monorepo. Split only after APIs are stable.

Possible layout:

```text
yuki/
  README.md
  AGENTS.md
  flake.nix
  build.zig
  build.zig.zon

  apps/
    yuki-cli/
    yuki-studio/        later

  src/
    core/
    backend/sdl/
    gpu/wgpu/
    render2d/
    render3d/           later
    luau/
    assets/
    content/
    world/
    input/
    audio/
    ui/

  modules/
    saves/
    inventory/
    dialogue/
    tilemap/
    animation/
    localization/

  sdk/
    luau/
      yuki/
      types/

  examples/
    hello_window/
    hello_luau/
    sprites/
    tiny_quest/

  docs/
    00_START_HERE.md
    01_VISION.md
    ...

  third_party/
    optional vendored deps
```

Not every folder must exist on day one.

## App targets

`yuki-cli` is the command-line tool:

```text
yuki new
yuki dev
yuki check
yuki package
```

`yuki-studio` comes later and should be a native Yuki app.

## Source boundaries

`src/core` should stay small.

Renderer code belongs in:

```text
src/gpu
src/render2d
src/render3d
```

Game systems belong in:

```text
modules/
```

Luau-facing APIs belong in:

```text
sdk/luau/
```
