# 01. Vision

Yuki exists to reduce the amount of repeated game boilerplate.

Many games need the same foundations: input actions, saves, states, assets, UI, animation, dialogue, inventory, maps, localization, and data validation. Yuki should provide these as reusable systems without forcing the user into a heavy editor-first workflow from day one.

## Core idea

Yuki should feel like:

> A code-first engine with a exhausting game standard library.

Users should be able to write simple Luau code:

```lua
player.inventory:add(Items.Potion, 3)
Dialogue.start("dialogue.blacksmith_intro")
World.spawn(Prefabs.Slime, {
    position = Vec2.new(120, 80)
})
```

while Zig handles the hard parts: memory, rendering, assets, saves, validation, packaging, and native modules.

## Guiding principles

1. **2D first.** Build an excellent 2D engine before chasing 3D.
2. **Code-first first.** The first useful version should not depend on a visual editor.
3. **Yuki is built with Yuki.** The future editor should be a native Yuki app using Yuki UI and Yuki runtime.
4. **Luau is the game language.** Zig is the engine and extension language.
5. **Core stays small.** Game concepts live in modules, not in the kernel.
6. **Data should be buildable.** Development can be flexible; release builds should compile scripts and pack assets.
7. **Tools follow runtime.** Build tools around systems that already work.

## Non-goals for the early project

- Multi-language bindings.
- A full Unity/Godot-style editor at the start.
- A general-purpose 3D engine before Yuki2D works.
- Binary plugin ABI stability before source extensions work.
- Perfect cross-platform support before the desktop loop is solid.
