# 14. Input API

This document describes the current input API shape for Yuki2D and the direction
for future Luau bindings.

Input should expose player intent, not SDL or backend device details. SDL3 can
provide platform events, but game code should work with named actions, axes,
mouse state, and eventually standard gamepad concepts.

## Current Status

Yuki now has a Zig-side v0 input API that is good enough to build against for
the current milestone.

Implemented:

- keyboard key and mouse button enums;
- stable source names such as `"space"`, `"a"`, and `"left"`;
- mouse position, delta, wheel, and button state;
- typed action handles:
  `DigitalActionId`, `Axis1ActionId`, and `Axis2ActionId`;
- named action maps through `ActionRegistry`;
- `ActionMap` bindings for digital, axis1, and axis2 actions;
- multiple bindings feeding the same action;
- active action maps with priority and whole-map blocking;
- `InputSession` as the owned runtime input object;
- `InputSessionBuilder` for setup-time named registration;
- frame-local input events;
- named event, binding, context, and action descriptor readers;
- `NamedInputMapView` as the main map-scoped read API;
- demo runtime input built from the named map view.

This is not the final input system. It is the current stable foundation. The
major missing pieces are Luau bindings, gamepad support, data-file loading,
user rebinding, text input, and multiple local players.

## Current Shape

The runtime has two layers:

1. **Handle-based internals** for hot-path state and routing.
2. **Name-based views** for script/debug/tool-facing APIs.

The handle-based layer keeps input compact and predictable. The name-based layer
keeps authoring readable and is the model future Luau APIs should mirror.

## Core Concepts

### Physical Input

Physical input is data from a device:

- keyboard key;
- mouse button;
- mouse motion;
- mouse wheel;
- future gamepad button;
- future gamepad axis or stick.

Physical input belongs near the platform layer. Game scripts should rarely need
to read it directly.

### Source Names

Source names are stable strings for physical controls.

Examples:

```text
space
a
d
left
right
```

The current source-name helpers parse keyboard names and mouse button names
during setup. Mouse button names are button-local strings such as `"left"` and
`"right"`; source descriptors can still report `{ device = "mouse", control =
"left" }` for tooling/debug output.

Runtime bindings store enums, not strings.

### Action

An action is semantic game intent.

Examples:

```text
player.move
player.jump
ui.confirm
ui.cancel
debug.toggle_overlay
```

Actions are named in setup/content code, then resolved to compact typed handles
for runtime use.

### Action Value

Actions are typed:

```text
digital   bool state with pressed/released edges
axis1     f32 value
axis2     Vector2 value
```

Typed actions keep Zig validation clear and should make Luau type definitions
cleaner later.

### Binding

A binding maps one or more physical inputs into one action value.

Examples:

```text
space        -> player.jump
a/d          -> player.move.x
w/s          -> player.move.y
left mouse   -> pointer.select
```

Multiple bindings can feed the same action. The demo uses both WASD and arrow
keys for the same `player.move` axis2 action.

### Action Map

An action map is a named group of related actions and bindings.

Examples:

```text
gameplay
ui
debug
photo_mode
```

Maps can be pushed, popped, prioritized, and marked blocking.

### Active Map Stack

The runtime processes active maps by priority.

Example:

```text
debug_overlay
pause_menu
gameplay
```

Whole-map blocking is implemented now:

- non-blocking maps allow lower-priority maps to receive input too;
- blocking maps stop lower-priority maps behind them.

Per-action consumption is not implemented yet.

## Main Zig APIs

### InputSessionBuilder

`InputSessionBuilder` is the setup-time API for named maps, actions, bindings,
and initial active maps.

Example:

```zig
var builder = input.InputSessionBuilder.init();

_ = try builder.addMap("gameplay");
_ = try builder.addAxis2("gameplay", "player.move");
_ = try builder.addDigital("gameplay", "player.jump");

try builder.bindAxis2KeyNames(
    "gameplay",
    "player.move",
    "a",
    "d",
    "w",
    "s",
);

try builder.bindDigitalKeyName("gameplay", "player.jump", "space");
try builder.activateMap("gameplay");

var session = try builder.build();
```

### InputSession

`InputSession` owns:

- the action registry;
- the input router;
- resolved input state;
- frame-local input events.

The platform layer applies physical input through it:

```zig
try session.applyKey(.space, true, false);
try session.applyMouseButton(.left, true, input.Vector2.xy(32.0, 48.0));
session.applyMouseMotion(input.Vector2.xy(32.0, 48.0));
session.applyMouseWheel(input.Vector2.xy(0.0, -1.0), input.Vector2.xy(32.0, 48.0));
```

### NamedInputMapView

`NamedInputMapView` is the preferred API-facing read view for one map.

It exposes:

- current action values;
- mouse state;
- frame-local named events;
- active map state;
- registered action descriptors;
- named binding descriptors.

Example:

```zig
const gameplay = try session.namedMapViewByName("gameplay");

const move = try gameplay.axis2("player.move");
if (try gameplay.digitalPressed("player.jump")) {
    // jump
}

if (gameplay.canProcess()) {
    // map is active and not blocked by a higher-priority modal map
}
```

### Introspection Readers

The input module has read-only readers for tooling and future Luau bindings:

```zig
const actions = gameplay.actions();
const bindings = gameplay.bindings();
const events = gameplay.namedEvents();
const context = gameplay.namedContext();
```

These readers do not mutate runtime input state. They exist so debug UI, docs,
and generated bindings can inspect input without learning internal storage.

## Input Events

SDL/platform callbacks should not call Luau directly.

Current flow:

```text
SDL event arrives
  -> platform layer calls InputSession
  -> InputSession updates key/mouse state
  -> active action maps resolve semantic actions
  -> frame-local input events are recorded
  -> game code reads state or events during update
```

Current event kinds:

```text
action_pressed
action_released
axis1_changed
axis2_changed
mouse_moved
mouse_button_pressed
mouse_button_released
mouse_scrolled
```

Events are frame-local. Persistent game state should be stored by the caller.

## Keyboard Model

The current implementation uses a small engine-level `Key` enum and stable key
names. This is enough for the demo and for early gameplay input.

Still planned:

- better physical-key naming;
- layout-aware display names;
- logical/text input;
- IME support.

Movement bindings should continue to prefer physical keys. Text input should be
a separate future system.

## Gamepad Model

Gamepad support is not implemented yet.

The planned model is a standard gamepad abstraction:

```text
south button
east button
west button
north button
left shoulder
right shoulder
left trigger
right trigger
dpad
left stick
right stick
start
select
guide
```

Luau should not need to know whether a controller is Xbox, PlayStation, Switch,
or another supported controller.

## Luau Direction

Luau bindings should mirror the named map view shape, not SDL or wgpu-native
details.

Polling should be the primary gameplay API:

```lua
local input = yuki.input.map("gameplay")

function update(dt)
    local move = input:axis2("player.move")

    if input:pressed("player.jump") then
        player:jump()
    end

    player:move(move * player.speed * dt)
end
```

Frame-local events should be available for UI and one-shot logic:

```lua
local input = yuki.input.map("gameplay")

for event in input:events() do
    if event.kind == "action_pressed" and event.action == "ui.confirm" then
        menu:confirm()
    end
end
```

Map control should be explicit:

```lua
yuki.input.pushMap("gameplay")
yuki.input.pushMap("pause_menu", {
    priority = 100,
    blocking = true,
})

yuki.input.popMap("pause_menu")
```

The exact Luau names can change. The important shape is:

- named maps;
- typed named actions;
- setup-time binding validation;
- map-scoped polling;
- frame-local events;
- no backend dependency leakage.

## Completed Migration Work

The old simple input path has been moved into a fuller named action-map model.

Completed:

1. Typed action handles.
2. Named action registry.
3. `ActionMap` bindings grouped by map.
4. Active map stack with priority and blocking.
5. Key/mouse routing into typed action state.
6. Frame-local input event queue.
7. Demo controls on named actions.
8. `InputSession` and `InputSessionBuilder`.
9. Stable source names for setup.
10. Named events, bindings, context, and action descriptors.
11. `NamedInputMapView`.
12. Demo runtime consuming `NamedInputMapView`.

## Still Planned

- Luau binding implementation.
- Data-driven action map loading.
- Gamepad source types and bindings.
- Better physical/logical keyboard distinction.
- User-facing rebinding.
- Text input and IME.
- Multiple local players.
- Input recording/replay.
- Optional callback sugar over the event queue.

## Open Questions

- Should Luau scripts use raw action strings, generated constants, or both?
- Should map blocking stay whole-map only for the first Luau version?
- How much keyboard layout display data is needed before rebinding UI exists?
- When local multiplayer arrives, should player ownership belong to the map,
  the binding, or a separate input user object?
