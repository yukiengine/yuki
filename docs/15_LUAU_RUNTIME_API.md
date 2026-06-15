# 15. Luau Runtime API

This document describes the first Luau runtime API Yuki should implement.

The immediate goal is small:

```text
load one Luau script
  -> call init(ctx)
  -> call update(ctx, dt) every frame
  -> let the script read input and move one actor
```

The API should prove the scripting boundary before Yuki grows a larger component
system, hot reload model, package loader, or editor-facing reflection layer.

## Current Goal

The first milestone is:

> A Luau script moves a textured sprite in the current Yuki2D demo.

The script should be able to:

- load as a returned table;
- receive `init(ctx)` once;
- receive `update(ctx, dt)` every frame;
- read named input actions;
- look up one actor by key;
- read and assign actor position;
- use basic `Vector2` values.

Everything else is later.

## Script Shape

Scripts return a table.

```lua
local script = {}

function script.init(ctx)
end

function script.update(ctx, dt)
end

return script
```

Rules:

- returning a table is required;
- `init` is optional;
- `update` is optional;
- lifecycle fields must be functions when present;
- `ctx` is the official way to reach Yuki runtime APIs;
- scripts should not depend on global Yuki runtime objects in v0.

This shape is explicit, easy to validate from Zig, and can grow additional
lifecycle functions later.

## First Demo Script

The first useful script should look close to this:

```lua
local script = {}

local input = nil
local player = nil

function script.init(ctx)
    input = ctx.input:map("gameplay")
    player = ctx.world:requireActor("player")
end

function script.update(ctx, dt)
    local move = input:axis2("player.move")
    player.position = player.position + move * 240 * dt
end

return script
```

`input` and `player` are cacheable handles. `ctx` is not.

## Runtime Ownership

The Zig runtime owns the Luau VM and script lifecycle.

Planned Zig-side concepts:

```text
ScriptHost
  owns Luau state
  registers Yuki API tables
  loads scripts
  calls lifecycle functions

ScriptModule
  stores one loaded script table
  stores optional init/update references
  tracks disabled/error state

ScriptContext
  frame-local bridge into runtime systems
  exposes input, world, time, and logging APIs
```

`App` should eventually own a `ScriptHost`.

```text
App.beginFrame()
  input begins frame
  platform events update input

App.update(dt)
  script_host.update(ctx, dt)

App.render()
  scene renders
```

## Context Lifetime

`ctx` is valid only during a lifecycle callback.

Good:

```lua
function script.update(ctx, dt)
    local move = ctx.input:map("gameplay"):axis2("player.move")
end
```

Bad:

```lua
local saved_ctx = nil

function script.init(ctx)
    saved_ctx = ctx
end
```

Handles acquired from `ctx` may be cached when their API says so. The context
object itself should not be cached.

## Input API

The Luau input API should mirror `NamedInputMapView`.

```lua
local gameplay = ctx.input:map("gameplay")

local move = gameplay:axis2("player.move")
local selected = gameplay:pressed("pointer.select")
local mouse = gameplay:mousePosition()
```

Planned v0 methods:

```text
ctx.input:map(name) -> InputMap

InputMap:down(action) -> boolean
InputMap:pressed(action) -> boolean
InputMap:released(action) -> boolean
InputMap:axis1(action) -> number
InputMap:axis2(action) -> Vector2
InputMap:mousePosition() -> Vector2
InputMap:mouseDelta() -> Vector2
InputMap:mouseWheel() -> Vector2
InputMap:events() -> iterator
```

Input map handles are cacheable across frames.

```lua
local gameplay = nil

function script.init(ctx)
    gameplay = ctx.input:map("gameplay")
end

function script.update(ctx, dt)
    local move = gameplay:axis2("player.move")
end
```

A cached input map handle should still only be used while the engine is inside a
script callback. Calling it outside runtime callbacks should error.

## World API

The first world API should be intentionally narrow.

```lua
local player = ctx.world:requireActor("player")
player.position = player.position + Vector2.new(8, 0)
```

Actor lookup uses a unique **actor key**.

Do not use:

- display name, because it is editor/UI-facing and may not be unique;
- tag, because tags are group/query metadata and are not unique.

Planned v0 methods:

```text
ctx.world:actor(key) -> Actor?
ctx.world:requireActor(key) -> Actor
```

`actor(key)` returns `nil` when missing.

`requireActor(key)` errors when missing.

Examples should use `requireActor` when the script cannot function without the
actor.

## Actor Handles

Actor handles are script-facing references to Zig-owned actors.

Rules:

- handles do not expose raw Zig pointers;
- handles should be generation-checked;
- stale handles error on property access or mutation;
- `actor:isAlive()` returns whether the handle still points to a live actor.

Example:

```lua
if player:isAlive() then
    player.position = player.position + Vector2.new(1, 0)
end
```

If the actor has been destroyed:

```lua
player:isAlive() -- false
player.position  -- error
```

Silent no-op behavior should be avoided because it hides script bugs.

## Actor Properties

The v0 actor API should start with position only.

```lua
local p = player.position
player.position = p + Vector2.new(10, 0)
```

Later properties can include rotation, scale, visibility, sprite, animation, and
tags.

## Vector2 Values

`Vector2` values are immutable.

```lua
local p = player.position
player.position = Vector2.new(10, p.y)
```

This should not work in v0:

```lua
player.position.x = 10
```

Reason: assigning to `position.x` creates confusing writeback rules. Whole-value
assignment is clearer and maps better to Zig-owned actor storage.

Ergonomic helpers can come later:

```lua
player:setPosition(10, player.position.y)
player:translate(Vector2.new(4, 0))
```

## Standard Libraries

Expose a small deterministic Luau environment.

Allowed by default:

- `assert`, `error`, `pcall`, `xpcall`;
- `pairs`, `ipairs`, `next`;
- `type`, `typeof`, `tonumber`, `tostring`;
- `math`, `string`, `table`, `utf8`;
- `print`, routed to Yuki logging.

Not exposed by default:

- `io`;
- `os`;
- `debug`;
- unrestricted `require`;
- filesystem access;
- network access.

Yuki should provide its own module/content loading API instead of exposing raw
host filesystem access.

## Error Behavior

Errors should be reported with:

- script path or script name;
- lifecycle function name;
- Luau traceback when available.

V0 behavior:

- `init` error: script fails to load and does not receive updates;
- `update` error: report once and disable that script until reload;
- engine keeps running in dev mode when possible.

This prevents one script error from killing the whole app loop during
development.

## Scene Script vs Component Script

The first script shape is a scene/runtime script module.

```lua
function script.update(ctx, dt)
end
```

Future actor components can reuse the returned-table style, but they should have
an actor-specific contract.

Possible future shape:

```lua
function script.update(ctx, actor, dt)
end
```

Do not design the full component system in the first runtime pass.

## First Implementation Steps

1. Add Luau as a linked dependency in the build/dev shell.
2. Add a minimal `ScriptHost` that can create and destroy a Luau state.
3. Load one `.luau` file and require it to return a table.
4. Resolve optional `init` and `update` functions.
5. Call `init(ctx)` once.
6. Call `update(ctx, dt)` every frame.
7. Bind `Vector2`.
8. Bind enough `ctx.input` to read `player.move`.
9. Bind enough `ctx.world` to move the demo player.

Each step should keep `zig build test` and `zig build run` working.

## Later Work

- Multiple scripts.
- Script module loading.
- Hot reload.
- Bytecode compilation and packaging.
- Generated `.d.luau` definitions.
- Actor component scripts.
- Events delivered to scripts.
- Script-owned timers.
- Data-driven action maps.
- Better script error UI.

## Open Questions

- Should script modules be loaded from loose files, bytecode, or both in dev?
- What should the first Yuki module loader look like?
- Should actor keys live directly on scene actors or in a separate script
  registry?
- Should script disable-on-error be configurable per project?
