# 14. Input API

This document describes the intended input API shape for Yuki2D.

Input should expose player intent, not backend device details. SDL3 can provide
raw events, but Luau code should work with actions, axes, mouse state, and
standard gamepad concepts.

## Current Status

Yuki currently has:

- keyboard keys;
- mouse buttons, position, delta, and wheel;
- action handles;
- a simple key-to-action `InputMap`;
- pressed, released, and held state;
- a basic action axis helper.

This is useful as a foundation, but it is still too close to the internal
runtime shape. The public API should move toward named, typed actions grouped
into action maps.

## Goals

- Let games define named actions such as `player.jump` or `ui.confirm`.
- Support action maps such as `gameplay`, `ui`, and `debug`.
- Allow multiple active maps with predictable priority.
- Support digital actions, 1D axes, and 2D axes.
- Support keyboard, mouse, and standard gamepad inputs.
- Keep SDL and controller backend details out of Luau.
- Resolve string/content names to handles before hot-path runtime use.
- Expose both polling and frame-local input events to Luau.

## Non-Goals For Now

- Text input and IME.
- User-facing rebinding UI.
- Multiple local players.
- Input recording/replay.
- Raw controller APIs in Luau.
- Full action callback subscription lifetime management.

These can be added later without changing the core model.

## Core Concepts

### Physical Input

Physical input is data from a device:

- keyboard key;
- mouse button;
- mouse motion;
- mouse wheel;
- gamepad button;
- gamepad axis or stick.

Physical input belongs near the platform layer. Game scripts should rarely need
to read it directly.

### Action

An action is semantic game intent.

Examples:

```text
player.move
player.jump
player.dash
ui.confirm
ui.cancel
debug.toggle_overlay
```

Actions are named in content/API code, then resolved to compact handles for
runtime use.

### Action Value

Actions should be typed. The first value kinds should be:

```text
digital   bool state with pressed/released edges
axis1     f32 value, usually -1.0 to 1.0
axis2     Vector2 value, usually normalized or clamped
```

Avoid making every action return every possible type. Typed actions make Luau
type definitions and Zig validation much cleaner.

### Binding

A binding maps one or more physical inputs into one action value.

Examples:

```text
Space                    -> player.jump
GamepadSouth             -> player.jump
A/D                      -> player.move.x
W/S                      -> player.move.y
GamepadLeftStick         -> player.move
Escape                   -> ui.cancel
MouseLeft                -> ui.activate
```

Multiple bindings can feed the same action.

### Action Map

An action map is a named group of related actions and bindings.

Examples:

```text
gameplay
ui
debug
photo_mode
```

Games should be able to enable, disable, push, or pop maps without rebuilding
the input system.

### Active Map Stack

The runtime should process active maps by priority.

Example:

```text
debug_overlay
pause_menu
gameplay
```

This allows debug shortcuts, modal UI, and gameplay controls to coexist.

The first version can support simple whole-map blocking:

- non-blocking maps allow lower-priority maps to receive input too;
- blocking maps stop lower-priority maps from receiving matching input.

More detailed per-action consumption can come later if needed.

## Keyboard Model

Keyboard input should distinguish physical keys from layout-resolved symbols.

Physical keys are useful for movement:

```text
the key in the W position
the key in the A position
the key in the S position
the key in the D position
```

Logical symbols are useful for shortcuts and text-like commands:

```text
the character W
the character /
the character =
```

This matters for layouts such as QWERTY and AZERTY. A movement binding usually
wants physical keys. A text shortcut may want logical symbols.

The first API should prefer physical keys for gameplay bindings and leave text
input as a separate future system.

## Gamepad Model

Gamepad input should use a standard gamepad abstraction:

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

Backend-specific controller details should stay in the platform layer. Advanced
raw controller access can be considered later.

## Luau API Draft

Polling should be the primary gameplay API:

```lua
local Input = require("@yuki/input")
local Actions = require("game/actions")

function update(dt)
    local move = Input.axis2(Actions.PlayerMove)

    if Input.pressed(Actions.PlayerJump) then
        player:jump()
    end

    player:move(move * player.speed * dt)
end
```

Frame-local events should be the primary UI and one-shot API:

```lua
for event in Input.events() do
    if event.kind == "action_pressed" and event.action == Actions.UiConfirm then
        menu:confirm()
    end
end
```

Map control should be explicit:

```lua
Input.pushMap(InputMaps.Gameplay)
Input.pushMap(InputMaps.PauseMenu, {
    priority = 100,
    blocking = true,
})

Input.popMap(InputMaps.PauseMenu)
```

Action definitions can start as data:

```lua
return {
    maps = {
        gameplay = {
            actions = {
                move = { type = "axis2" },
                jump = { type = "digital" },
            },

            bindings = {
                { action = "move", source = { keyboard_axis2 = {
                    up = "KeyW",
                    down = "KeyS",
                    left = "KeyA",
                    right = "KeyD",
                } } },

                { action = "move", source = { gamepad_stick = "left" } },
                { action = "jump", source = { key = "Space" } },
                { action = "jump", source = { gamepad_button = "south" } },
            },
        },
    },
}
```

The exact data syntax can change. The important shape is typed actions,
bindings, and named maps.

## Input Events

Do not call Luau directly from SDL input callbacks.

Preferred flow:

```text
SDL event arrives
  -> Zig records raw device state
  -> Zig resolves active action maps once per frame
  -> Zig creates frame-local input events
  -> Luau reads or iterates events during update
```

Initial event kinds:

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

Events are frame-local. If a script wants persistent state, it should store that
state itself or use polling.

Example event value:

```lua
{
    kind = "action_pressed",
    action = Actions.UiConfirm,
    map = InputMaps.Ui,
    device = "keyboard",
    frame = 1234,
}
```

Callbacks such as `Input.onPressed(...)` can be added later as sugar over the
same event queue. They should not be the first implementation.

## Zig API Draft

Zig should keep the hot path handle-based:

```zig
const move = input.Axis2Id.fromIndex(0);
const jump = input.ActionId.fromIndex(1);

const move_value = input_state.axis2(move);
if (input_state.pressed(jump)) {
    // jump
}
```

The public façade can expose named registration and lookup:

```zig
const gameplay = try registry.addMap("gameplay");
const move = try registry.addAxis2(gameplay, "player.move");
const jump = try registry.addDigital(gameplay, "player.jump");

try registry.bindKeyAxis2(gameplay, move, .{
    .up = .key_w,
    .down = .key_s,
    .left = .key_a,
    .right = .key_d,
});

try registry.bindGamepadButton(gameplay, jump, .south);
```

This keeps authoring readable while runtime state stays compact.

## Suggested Runtime Layers

```text
SDL/platform input
  raw device state
  action registry and bindings
  active map stack
  resolved action state
  frame-local input event queue
  Yuki2D / Luau API
```

Only the top layer should shape Luau. The lower layers can stay Zig-focused.

## Migration Plan

1. Rename the current simple `InputMap` concept internally if needed so
   `ActionMap` can mean a named game-facing map.
2. Add typed action handles:
   `DigitalActionId`, `Axis1ActionId`, and `Axis2ActionId`.
3. Add an action registry that maps names to typed action handles.
4. Add `ActionMap` data with bindings grouped by map.
5. Add an active map stack with priority and whole-map blocking.
6. Resolve raw key/mouse state into typed action state once per frame.
7. Add a frame-local input event queue.
8. Update the demo to use named actions through the new API.
9. Shape the future Luau bindings around the same names and event model.

Each step should keep `zig build run` working.

## Open Questions

- Should action names be plain strings, generated constants, or both?
- Should map blocking be whole-map only at first?
- Should mouse actions live in the same action map model or in a separate
  pointer API with optional action bindings?
- How much keyboard layout display data should be exposed before there is a
  rebinding UI?
- When local multiplayer arrives, should player ownership belong to the map,
  the binding, or a separate input user object?
