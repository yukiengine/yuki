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
    try expectDigital(&registry, gameplay, demo.Controls.move_left_name, demo.Controls.move_left);
    try expectDigital(&registry, gameplay, demo.Controls.move_right_name, demo.Controls.move_right);
    try expectDigital(&registry, gameplay, demo.Controls.move_up_name, demo.Controls.move_up);
    try expectDigital(&registry, gameplay, demo.Controls.move_down_name, demo.Controls.move_down);
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

fn expectDigital(
    registry: *const input.ActionRegistry,
    map: input.ActionMapId,
    name: []const u8,
    expected: input.DigitalActionId,
) !void {
    const found = registry.findDigital(map, name) orelse return error.ExpectedAction;
    try std.testing.expectEqual(expected.index, found.index);
}
