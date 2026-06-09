# 08. Luau

Luau is the default game language for Yuki.

Zig builds the engine. Luau builds the game.

## Role

Use Luau for:

- gameplay scripts;
- components;
- item effects;
- dialogue logic;
- UI screen logic;
- enemy behavior;
- content definitions;
- small game-specific modules.

Use Zig for:

- renderer;
- assets;
- world storage;
- save backend;
- native modules;
- performance-critical systems.

## Strict mode

Project templates should use:

```lua
--!strict
```

Yuki should generate `.d.luau` files for engine APIs, content IDs, and native extensions.

## Packaging

Development can use loose `.luau` files.

Release builds should compile Luau to bytecode and pack it with assets/content.

```text
Luau source
  -> analyze/check
  -> bytecode
  -> game.pak
```

Raw source should not be shipped by default.

## Object model

Avoid classic Lua OOP as the default.

Prefer engine components:

```lua
return Component.define("SlimeAI", {
    update = function(self, dt)
        if self:canSee(Player) then
            self.body:moveToward(Player.position, dt)
        end
    end,
})
```

## Bridge rules

- Luau objects should hold handles to Zig data.
- Do not expose raw pointers.
- Avoid thousands of tiny Luau-to-Zig calls per frame.
- Prefer high-level batch operations.
