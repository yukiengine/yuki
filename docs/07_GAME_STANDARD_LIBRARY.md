# 07. Game Standard Library

The game standard library is where Yuki becomes more than a renderer.

It should provide common game systems as reusable modules.

## First modules

### Scenes and state stack

Menus, gameplay, pause overlays, loading screens, and transitions.

### Saves

Save slots, autosaves, versioning, migrations, and module-owned save data.

### Inventory and items

Item definitions, stacks, containers, equipment, item effects, and loot tables.

### Dialogue

Actors, lines, choices, conditions, effects, localization keys, and save state.

### Localization

Text keys, language files, missing-key checks, and runtime lookup.

### Tilemaps and maps

Tile layers, object layers, collisions, triggers, spawn points, and map loading.

### Animation

Sprite sheets, clips, frame events, hitboxes/hurtboxes later.

### UI

Runtime UI for games first, Studio UI later.

## Design rules

- Modules should expose simple Luau APIs.
- Zig owns state and invariants.
- Luau owns game rules and callbacks.
- Content should validate before runtime when possible.
- Modules should be useful without Studio.

## Example target

A tiny top-down RPG should be possible with the standard library:

- main menu;
- player controller;
- map;
- NPC dialogue;
- inventory;
- save/load;
- one enemy;
- one item;
- UI screens.
