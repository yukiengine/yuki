# 04. API Shape

The public API should be simple from Luau and explicit from Zig.

Luau is for normal game code. Zig is for engine internals and native extensions.

## Luau API style

Users should call game concepts:

```lua
World.spawn(Prefabs.Player, { position = Vector2.new(32, 64) })
player.inventory:add(Items.Potion, 3)
Dialogue.start("dialogue.blacksmith_intro")
UI.open("inventory")
Audio.play("sfx.pickup")
```

Avoid exposing raw engine internals:

```lua
-- Avoid this shape.
Core.addComponent(entity, "Transform", { x = 0, y = 0 })
WGPU.createBuffer(...)
SDL.pollEvent(...)
```

## Core Luau packages

Early packages:

```text
@yuki/game
@yuki/world
@yuki/component
@yuki/prefab
@yuki/input
@yuki/time
@yuki/events
@yuki/assets
@yuki/audio
@yuki/render2d
@yuki/ui
@yuki/debug
```

Later packages:

```text
@yuki/saves
@yuki/inventory
@yuki/dialogue
@yuki/localization
@yuki/tilemap
@yuki/animation
@yuki/ai
```

## Component model

Do not make users write Lua metatable OOP by default.

Prefer an engine component API:

```lua
return Component.define("PlayerController", {
    props = {
        speed = Component.number(120),
    },

    update = function(self, dt)
        local move = Input.axis2("move")
        self.body:move(move * self.speed * dt)
    end,
})
```

Yuki should provide lifecycle, state, editor inspection, hot reload, and save hooks.

## Zig API style

Zig APIs should be explicit and backend-facing:

```zig
const eg = @import("yuki");

pub const Module = eg.NativeModule(.{
    .id = "mygame.combat",
    .register = register,
});

fn register(ctx: *eg.ModuleContext) !void {
    try ctx.luau.exportModule("Combat", .{
        .applyDamage = applyDamage,
    });
}
```

Zig modules can register:

- systems;
- components;
- content schemas;
- Luau functions;
- save serializers;
- Studio panels later.

## API rules

- Luau APIs should be high-level.
- Zig APIs should be explicit.
- Do not leak SDL or wgpu-native into user scripts.
- Cross the Luau/Zig boundary in batches where possible.
- Use generated Luau type definitions for autocomplete and checking.

See [14. Input API](14_INPUT_API.md) for the planned input action-map shape.
