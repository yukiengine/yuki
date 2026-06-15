//! Demo input integration tests.
//!
//! These tests verify that the demo uses the new InputRouter path while keeping
//! the current gameplay controls behavior.

const std = @import("std");
const demo = @import("demo.zig");
const yuki2d = @import("yuki2d.zig");

const input = yuki2d.input;

test "demo controls install gameplay map in router" {
    const router = demo.Controls.defaultInputRouter();

    try std.testing.expect(router.hasMap(demo.Controls.gameplay_map));
    try std.testing.expect(router.activeContext().containsMap(demo.Controls.gameplay_map));
    try std.testing.expect(router.activeContext().canProcessMap(demo.Controls.gameplay_map));
}

test "demo controls route movement through input router" {
    const router = demo.Controls.defaultInputRouter();
    var state = input.State.init();

    try router.applyKey(&state, .d, true, false);
    try router.applyKey(&state, .w, true, false);

    const frame_input = demo.Input.fromState(&state);

    try std.testing.expectEqual(@as(f32, 1.0), frame_input.move_x);
    try std.testing.expectEqual(@as(f32, -1.0), frame_input.move_y);
}

test "demo controls bind mouse button to select action" {
    const router = demo.Controls.defaultInputRouter();

    var state = input.State.init();
    var events = input.InputEventQueue.init();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        true,
        input.Vector2.xy(24.0, 32.0),
    );

    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expect(frame_input.select_down);
    try std.testing.expect(frame_input.select_pressed);
    try std.testing.expect(!frame_input.select_released);
    try std.testing.expectEqual(@as(f32, 24.0), frame_input.mouse_screen.x);
    try std.testing.expectEqual(@as(f32, 32.0), frame_input.mouse_screen.y);
}

test "demo controls keep opposite directions neutral" {
    const router = demo.Controls.defaultInputRouter();
    var state = input.State.init();

    try router.applyKey(&state, .a, true, false);
    try router.applyKey(&state, .d, true, false);

    const frame_input = demo.Input.fromState(&state);

    try std.testing.expectEqual(@as(f32, 0.0), frame_input.move_x);
}

test "demo controls expose one-frame action presses" {
    const router = demo.Controls.defaultInputRouter();
    var state = input.State.init();

    try router.applyKey(&state, .f1, true, false);

    var frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.toggle_debug_pressed);

    state.beginFrame();

    frame_input = demo.Input.fromState(&state);
    try std.testing.expect(!frame_input.toggle_debug_pressed);
}

test "demo controls preserve compatibility input map" {
    var map = demo.Controls.defaultInputMap();
    var state = input.State.init();

    map.applyKey(&state, .space, true, false);

    var frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.pause_animation_pressed);

    state.beginFrame();

    map.applyMouseButton(
        &state,
        .left,
        true,
        input.Vector2.xy(0.0, 0.0),
    );

    frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.select_pressed);
}

test "demo controls build input session with active gameplay map" {
    var session = demo.Controls.defaultInputSession();

    try std.testing.expect(session.inputRouter().hasMap(demo.Controls.gameplay_map));
    try std.testing.expect(session.activeContext().containsMap(demo.Controls.gameplay_map));
    try std.testing.expect(session.activeContext().canProcessMap(demo.Controls.gameplay_map));

    const gameplay = session.actionRegistry().findMap(demo.Controls.gameplay_map_name) orelse {
        return error.ExpectedGameplayMap;
    };

    try std.testing.expect(gameplay.eql(demo.Controls.gameplay_map));
}

test "demo input session routes named gameplay controls" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(.d, true, false);
    try session.applyKey(.w, true, false);
    try session.applyMouseButton(
        .left,
        true,
        input.Vector2.xy(18.0, 28.0),
    );

    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        session.inputState(),
        session.inputEvents(),
    ));

    try std.testing.expectEqual(@as(f32, 1.0), frame_input.move_x);
    try std.testing.expectEqual(@as(f32, -1.0), frame_input.move_y);
    try std.testing.expect(frame_input.select_pressed);
    try std.testing.expectEqual(@as(f32, 18.0), frame_input.mouse_screen.x);
    try std.testing.expectEqual(@as(f32, 28.0), frame_input.mouse_screen.y);
}

test "demo input session exposes named frame" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(.f1, true, false);
    try session.applyMouseButton(
        .left,
        true,
        input.Vector2.xy(40.0, 64.0),
    );

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);

    try std.testing.expect(try named.digitalPressed(demo.Controls.toggle_debug_name));
    try std.testing.expect(try named.digitalDown(demo.Controls.select_name));
    try std.testing.expect(try named.hasActionPressed(demo.Controls.select_name));
}

test "demo select action release is one-frame input" {
    const router = demo.Controls.defaultInputRouter();

    var state = input.State.init();
    var events = input.InputEventQueue.init();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        true,
        input.Vector2.xy(0.0, 0.0),
    );

    state.beginFrame();
    events.beginFrame();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        false,
        input.Vector2.xy(0.0, 0.0),
    );

    var frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expect(!frame_input.select_down);
    try std.testing.expect(!frame_input.select_pressed);
    try std.testing.expect(frame_input.select_released);

    state.beginFrame();
    events.beginFrame();

    frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expect(!frame_input.select_down);
    try std.testing.expect(!frame_input.select_pressed);
    try std.testing.expect(!frame_input.select_released);
}

test "demo controls expose named action registry" {
    var registry = demo.Controls.defaultActionRegistry();
    const gameplay = registry.findMap(demo.Controls.gameplay_map_name) orelse return error.ExpectedMap;

    try std.testing.expect(gameplay.eql(demo.Controls.gameplay_map));
    try expectAxis2(&registry, gameplay, demo.Controls.move_name, demo.Controls.move);
    try std.testing.expectEqual(@as(usize, 7), registry.digitalCount());
    try std.testing.expectEqual(@as(usize, 1), registry.axis2Count());

    try expectDigital(&registry, gameplay, demo.Controls.zoom_in_name, demo.Controls.zoom_in);
    try expectDigital(&registry, gameplay, demo.Controls.zoom_out_name, demo.Controls.zoom_out);
    try expectDigital(&registry, gameplay, demo.Controls.pause_animation_name, demo.Controls.pause_animation);
    try expectDigital(&registry, gameplay, demo.Controls.reset_animation_name, demo.Controls.reset_animation);
    try expectDigital(&registry, gameplay, demo.Controls.quit_name, demo.Controls.quit);
    try expectDigital(&registry, gameplay, demo.Controls.toggle_debug_name, demo.Controls.toggle_debug);
    try expectDigital(&registry, gameplay, demo.Controls.select_name, demo.Controls.select);
}

test "demo action map is built from named control bindings" {
    var map = demo.Controls.defaultActionMap();
    var state = input.State.init();

    map.applyKey(&state, .f1, true, false);
    var frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.toggle_debug_pressed);

    state.beginFrame();

    map.applyMouseButton(
        &state,
        .left,
        true,
        input.Vector2.xy(8.0, 16.0),
    );

    frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.select_pressed);
    try std.testing.expectEqual(@as(f32, 8.0), frame_input.mouse_screen.x);
    try std.testing.expectEqual(@as(f32, 16.0), frame_input.mouse_screen.y);
}

test "demo router uses named control map" {
    const router = demo.Controls.defaultInputRouter();

    var state = input.State.init();
    var events = input.InputEventQueue.init();

    try router.applyKeyWithEvents(&state, &events, .d, true, false);
    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        true,
        input.Vector2.xy(12.0, 24.0),
    );

    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expectEqual(@as(f32, 1.0), frame_input.move_x);
    try std.testing.expect(frame_input.select_pressed);
}

test "demo controls expose setup builder with stable ids" {
    const builder = demo.Controls.defaultInputSessionBuilder();
    const registry = builder.registry();

    const gameplay = registry.findMap(demo.Controls.gameplay_map_name) orelse return error.ExpectedMap;

    try std.testing.expect(gameplay.eql(demo.Controls.gameplay_map));
    try std.testing.expectEqual(@as(usize, 1), builder.mapCount());
    try std.testing.expectEqual(@as(usize, 1), builder.activeMapCount());

    try expectAxis2(registry, gameplay, demo.Controls.move_name, demo.Controls.move);
    try std.testing.expectEqual(@as(usize, 7), registry.digitalCount());
    try std.testing.expectEqual(@as(usize, 1), registry.axis2Count());
    try expectDigital(registry, gameplay, demo.Controls.zoom_in_name, demo.Controls.zoom_in);
    try expectDigital(registry, gameplay, demo.Controls.zoom_out_name, demo.Controls.zoom_out);
    try expectDigital(registry, gameplay, demo.Controls.pause_animation_name, demo.Controls.pause_animation);
    try expectDigital(registry, gameplay, demo.Controls.reset_animation_name, demo.Controls.reset_animation);
    try expectDigital(registry, gameplay, demo.Controls.quit_name, demo.Controls.quit);
    try expectDigital(registry, gameplay, demo.Controls.toggle_debug_name, demo.Controls.toggle_debug);
    try expectDigital(registry, gameplay, demo.Controls.select_name, demo.Controls.select);
}

test "demo controls build action map through setup builder" {
    const builder = demo.Controls.defaultInputSessionBuilder();
    var map = try builder.actionMapByName(demo.Controls.gameplay_map_name);
    var state = input.State.init();

    map.applyKey(&state, .f1, true, false);
    var frame_input = demo.Input.fromState(&state);

    try std.testing.expect(frame_input.toggle_debug_pressed);

    state.beginFrame();

    map.applyMouseButton(
        &state,
        .left,
        true,
        input.Vector2.xy(12.0, 18.0),
    );

    frame_input = demo.Input.fromState(&state);

    try std.testing.expect(frame_input.select_pressed);
    try std.testing.expectEqual(@as(f32, 12.0), frame_input.mouse_screen.x);
    try std.testing.expectEqual(@as(f32, 18.0), frame_input.mouse_screen.y);
}

test "demo controls build router through setup builder" {
    const builder = demo.Controls.defaultInputSessionBuilder();
    const router = try builder.buildRouter();

    var state = input.State.init();
    var events = input.InputEventQueue.init();

    try router.applyKeyWithEvents(&state, &events, .d, true, false);
    try router.applyKeyWithEvents(&state, &events, .w, true, false);

    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expect(router.hasMap(demo.Controls.gameplay_map));
    try std.testing.expect(router.activeContext().containsMap(demo.Controls.gameplay_map));
    try std.testing.expectEqual(@as(f32, 1.0), frame_input.move_x);
    try std.testing.expectEqual(@as(f32, -1.0), frame_input.move_y);
}

test "demo controls build session through setup builder" {
    const builder = demo.Controls.defaultInputSessionBuilder();
    var session = try builder.build();

    try session.applyKey(.space, true, false);
    try session.applyMouseButton(
        .left,
        true,
        input.Vector2.xy(22.0, 44.0),
    );

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);

    try std.testing.expect(try named.digitalPressed(demo.Controls.pause_animation_name));
    try std.testing.expect(try named.digitalDown(demo.Controls.select_name));
    try std.testing.expect(try named.hasActionPressed(demo.Controls.select_name));
}

test "demo movement is exposed as a typed axis2 action" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(.d, true, false);
    try session.applyKey(.w, true, false);

    const frame = yuki2d.input_frame.Frame.init(
        session.inputState(),
        session.inputEvents(),
    );

    const move = frame.axis2(demo.Controls.move);
    const frame_input = demo.Input.fromFrame(frame);

    try std.testing.expectEqual(@as(f32, 1.0), move.x);
    try std.testing.expectEqual(@as(f32, -1.0), move.y);
    try std.testing.expectEqual(@as(f32, 1.0), frame_input.move_x);
    try std.testing.expectEqual(@as(f32, -1.0), frame_input.move_y);
}

test "demo movement axis supports arrow aliases" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(.right, true, false);
    try session.applyKey(.up, true, false);

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);
    const move = try named.axis2(demo.Controls.move_name);

    try std.testing.expectEqual(@as(f32, 1.0), move.x);
    try std.testing.expectEqual(@as(f32, -1.0), move.y);
}

test "demo movement axis keeps opposite directions neutral" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(.a, true, false);
    try session.applyKey(.d, true, false);
    try session.applyKey(.w, true, false);
    try session.applyKey(.s, true, false);

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);
    const move = try named.axis2(demo.Controls.move_name);
    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        session.inputState(),
        session.inputEvents(),
    ));

    try std.testing.expectEqual(@as(f32, 0.0), move.x);
    try std.testing.expectEqual(@as(f32, 0.0), move.y);
    try std.testing.expectEqual(@as(f32, 0.0), frame_input.move_x);
    try std.testing.expectEqual(@as(f32, 0.0), frame_input.move_y);
}

test "demo movement axis emits frame-local axis2 event" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(.d, true, false);

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);
    const axis_event = try named.firstAxis2Changed(demo.Controls.move_name) orelse {
        return error.ExpectedAxis2Event;
    };

    try std.testing.expect(axis_event.map.eql(demo.Controls.gameplay_map));
    try std.testing.expectEqual(demo.Controls.move.index, axis_event.action.index);
    try std.testing.expectEqual(@as(f32, 0.0), axis_event.previous.x);
    try std.testing.expectEqual(@as(f32, 0.0), axis_event.previous.y);
    try std.testing.expectEqual(@as(f32, 1.0), axis_event.value.x);
    try std.testing.expectEqual(@as(f32, 0.0), axis_event.value.y);
}

test "demo movement is only registered as a vector action" {
    var registry = demo.Controls.defaultActionRegistry();
    const gameplay = registry.findMap(demo.Controls.gameplay_map_name) orelse return error.ExpectedMap;

    try expectMissingAction(&registry, gameplay, "player.move_left");
    try expectMissingAction(&registry, gameplay, "player.move_right");
    try expectMissingAction(&registry, gameplay, "player.move_up");
    try expectMissingAction(&registry, gameplay, "player.move_down");

    const movement = registry.findAction(gameplay, demo.Controls.move_name) orelse {
        return error.ExpectedAction;
    };

    try std.testing.expectEqual(input.ActionKind.axis2, movement.kind());
}

test "demo movement axis emits named vector event" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(try input.parseKey(demo.Controls.move_left_key_name), true, false);

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);
    const reader = named.namedReader();

    const event = reader.firstAxis2Changed(demo.Controls.move_name) orelse {
        return error.ExpectedAxis2Event;
    };

    const source_name = input.sourceControlName(event.source) orelse {
        return error.ExpectedSourceName;
    };

    try std.testing.expect(event.map.eql(demo.Controls.gameplay_map));
    try std.testing.expectEqual(demo.Controls.move.index, event.action.index);
    try std.testing.expectEqualStrings(demo.Controls.gameplay_map_name, event.map_name);
    try std.testing.expectEqualStrings(demo.Controls.move_name, event.action_name);
    try std.testing.expectEqual(@as(f32, 0.0), event.previous.x);
    try std.testing.expectEqual(@as(f32, 0.0), event.previous.y);
    try std.testing.expectEqual(@as(f32, -1.0), event.value.x);
    try std.testing.expectEqual(@as(f32, 0.0), event.value.y);
    try std.testing.expectEqualStrings("keyboard", source_name.device);
    try std.testing.expectEqualStrings(demo.Controls.move_left_key_name, source_name.control);
}

test "demo controls expose valid stable source names" {
    try expectKeyName(demo.Controls.quit_key_name, .escape);
    try expectKeyName(demo.Controls.pause_animation_key_name, .space);
    try expectKeyName(demo.Controls.reset_animation_key_name, .r);

    try expectKeyName(demo.Controls.move_left_key_name, .a);
    try expectKeyName(demo.Controls.move_right_key_name, .d);
    try expectKeyName(demo.Controls.move_up_key_name, .w);
    try expectKeyName(demo.Controls.move_down_key_name, .s);

    try expectKeyName(demo.Controls.move_left_alt_key_name, .left);
    try expectKeyName(demo.Controls.move_right_alt_key_name, .right);
    try expectKeyName(demo.Controls.move_up_alt_key_name, .up);
    try expectKeyName(demo.Controls.move_down_alt_key_name, .down);

    try expectKeyName(demo.Controls.zoom_out_key_name, .q);
    try expectKeyName(demo.Controls.zoom_in_key_name, .e);
    try expectKeyName(demo.Controls.toggle_debug_key_name, .f1);

    try expectMouseButtonName(demo.Controls.select_mouse_button_name, .left);
}

test "demo controls bind source-name keyboard actions" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(try input.parseKey(demo.Controls.pause_animation_key_name), true, false);
    try session.applyKey(try input.parseKey(demo.Controls.reset_animation_key_name), true, false);
    try session.applyKey(try input.parseKey(demo.Controls.toggle_debug_key_name), true, false);

    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        session.inputState(),
        session.inputEvents(),
    ));

    try std.testing.expect(frame_input.pause_animation_pressed);
    try std.testing.expect(frame_input.reset_animation_pressed);
    try std.testing.expect(frame_input.toggle_debug_pressed);
}

test "demo controls bind source-name movement aliases" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(try input.parseKey(demo.Controls.move_right_alt_key_name), true, false);
    try session.applyKey(try input.parseKey(demo.Controls.move_up_alt_key_name), true, false);

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);
    const move = try named.axis2(demo.Controls.move_name);
    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        session.inputState(),
        session.inputEvents(),
    ));

    try std.testing.expectEqual(@as(f32, 1.0), move.x);
    try std.testing.expectEqual(@as(f32, -1.0), move.y);
    try std.testing.expectEqual(@as(f32, 1.0), frame_input.move_x);
    try std.testing.expectEqual(@as(f32, -1.0), frame_input.move_y);
}

test "demo controls bind source-name mouse selection" {
    var session = demo.Controls.defaultInputSession();

    try session.applyMouseButton(
        try input.parseMouseButton(demo.Controls.select_mouse_button_name),
        true,
        input.Vector2.xy(64.0, 96.0),
    );

    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        session.inputState(),
        session.inputEvents(),
    ));

    try std.testing.expect(frame_input.select_down);
    try std.testing.expect(frame_input.select_pressed);
    try std.testing.expectEqual(@as(f32, 64.0), frame_input.mouse_screen.x);
    try std.testing.expectEqual(@as(f32, 96.0), frame_input.mouse_screen.y);
}

test "demo named input events expose stable action and source names" {
    var session = demo.Controls.defaultInputSession();

    try session.applyKey(try input.parseKey(demo.Controls.toggle_debug_key_name), true, false);

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);
    const reader = named.namedReader();

    const event = reader.firstActionPressed(demo.Controls.toggle_debug_name) orelse {
        return error.ExpectedActionPressed;
    };

    const source_name = input.sourceControlName(event.source) orelse {
        return error.ExpectedSourceName;
    };

    try std.testing.expect(event.map.eql(demo.Controls.gameplay_map));
    try std.testing.expectEqual(demo.Controls.toggle_debug.index, event.action.index);
    try std.testing.expectEqualStrings(demo.Controls.gameplay_map_name, event.map_name);
    try std.testing.expectEqualStrings(demo.Controls.toggle_debug_name, event.action_name);
    try std.testing.expectEqualStrings("keyboard", source_name.device);
    try std.testing.expectEqualStrings(demo.Controls.toggle_debug_key_name, source_name.control);
}

test "demo named input events expose mouse source names" {
    var session = demo.Controls.defaultInputSession();

    try session.applyMouseButton(
        try input.parseMouseButton(demo.Controls.select_mouse_button_name),
        true,
        input.Vector2.xy(8.0, 12.0),
    );

    const named = try session.namedFrameByName(demo.Controls.gameplay_map_name);
    const reader = named.namedReader();

    const event = reader.firstActionPressed(demo.Controls.select_name) orelse {
        return error.ExpectedActionPressed;
    };

    const source_name = input.sourceControlName(event.source) orelse {
        return error.ExpectedSourceName;
    };

    try std.testing.expect(event.map.eql(demo.Controls.gameplay_map));
    try std.testing.expectEqual(demo.Controls.select.index, event.action.index);
    try std.testing.expectEqualStrings(demo.Controls.gameplay_map_name, event.map_name);
    try std.testing.expectEqualStrings(demo.Controls.select_name, event.action_name);
    try std.testing.expectEqualStrings("mouse", source_name.device);
    try std.testing.expectEqualStrings(demo.Controls.select_mouse_button_name, source_name.control);
}

test "demo controls expose named binding descriptors" {
    const builder = demo.Controls.defaultInputSessionBuilder();
    const registry = builder.registry();
    const gameplay = registry.findMap(demo.Controls.gameplay_map_name) orelse {
        return error.ExpectedMap;
    };
    const map = try builder.actionMapByName(demo.Controls.gameplay_map_name);

    const reader = input.NamedBindingReader.init(registry, gameplay, &map);

    try std.testing.expectEqual(@as(usize, 2), reader.countForAction(demo.Controls.move_name));
    try std.testing.expectEqual(@as(usize, 1), reader.countForAction(demo.Controls.pause_animation_name));
    try std.testing.expectEqual(@as(usize, 1), reader.countForAction(demo.Controls.select_name));

    const move = reader.firstForAction(demo.Controls.move_name) orelse {
        return error.ExpectedBinding;
    };

    switch (move) {
        .axis2_keys => |item| {
            try std.testing.expectEqualStrings(demo.Controls.gameplay_map_name, item.map_name);
            try std.testing.expectEqualStrings(demo.Controls.move_name, item.action_name);
            try std.testing.expectEqualStrings(demo.Controls.move_left_key_name, item.left_name);
            try std.testing.expectEqualStrings(demo.Controls.move_right_key_name, item.right_name);
            try std.testing.expectEqualStrings(demo.Controls.move_up_key_name, item.up_name);
            try std.testing.expectEqualStrings(demo.Controls.move_down_key_name, item.down_name);
        },
        else => return error.ExpectedAxis2Binding,
    }

    const select = reader.firstForAction(demo.Controls.select_name) orelse {
        return error.ExpectedBinding;
    };

    switch (select) {
        .mouse_button => |item| {
            try std.testing.expectEqualStrings(demo.Controls.select_name, item.action_name);
            try std.testing.expectEqualStrings(demo.Controls.select_mouse_button_name, item.button_name);
        },
        else => return error.ExpectedMouseButtonBinding,
    }
}

fn expectDigital(
    registry: *const input.ActionRegistry,
    map: input.ActionMapId,
    name: []const u8,
    expected: input.DigitalActionId,
) !void {
    const found = registry.findDigital(map, name) orelse return error.ExpectedAction;
    try std.testing.expectEqual(expected.index, found.index);
}

fn expectAxis2(
    registry: *const input.ActionRegistry,
    map: input.ActionMapId,
    name: []const u8,
    expected: input.Axis2ActionId,
) !void {
    const found = registry.findAxis2(map, name) orelse return error.ExpectedAction;
    try std.testing.expectEqual(expected.index, found.index);
}

fn expectKeyName(name: []const u8, expected: input.Key) !void {
    const parsed = try input.parseKey(name);
    try std.testing.expectEqual(expected, parsed);
    try std.testing.expectEqualStrings(name, input.keyNameAssert(parsed));
}

fn expectMouseButtonName(name: []const u8, expected: input.MouseButton) !void {
    const parsed = try input.parseMouseButton(name);
    try std.testing.expectEqual(expected, parsed);
    try std.testing.expectEqualStrings(name, input.mouseButtonNameAssert(parsed));
}

fn expectMissingAction(
    registry: *const input.ActionRegistry,
    map: input.ActionMapId,
    name: []const u8,
) !void {
    try std.testing.expect(registry.findAction(map, name) == null);
}
