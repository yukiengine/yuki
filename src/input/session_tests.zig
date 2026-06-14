//! Input session tests.
//!
//! These tests cover the owned input object that groups registry, router,
//! resolved state, and frame-local events.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMap = input.ActionMap;
const ActionRegistry = input.ActionRegistry;
const ActiveMapOptions = input.ActiveMapOptions;
const InputRouter = input.InputRouter;
const InputSession = input.InputSession;
const Vector2 = input.Vector2;

test "input session routes keyboard actions and exposes named frame" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var session = InputSession.init(registry, router);

    try session.applyKey(.space, true, false);

    try std.testing.expect(session.inputState().digitalDown(jump));
    try std.testing.expectEqual(@as(usize, 1), session.eventCount());

    const named = try session.namedFrameByName("gameplay");

    try std.testing.expect(try named.digitalDown("player.jump"));
    try std.testing.expect(try named.digitalPressed("player.jump"));
    try std.testing.expect(try named.hasActionPressed("player.jump"));
}

test "input session clears frame-local edges without releasing held state" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var session = InputSession.init(registry, router);

    try session.applyKey(.space, true, false);

    try std.testing.expect(session.inputState().digitalDown(jump));
    try std.testing.expect(session.inputState().digitalPressed(jump));
    try std.testing.expectEqual(@as(usize, 1), session.eventCount());

    session.beginFrame();

    try std.testing.expect(session.inputState().digitalDown(jump));
    try std.testing.expect(!session.inputState().digitalPressed(jump));
    try std.testing.expectEqual(@as(usize, 0), session.eventCount());
}

test "input session releases all input state" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");
    const select = try registry.addDigital(gameplay, "pointer.select");

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);
    try map.bindMouseButton(.left, select);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var session = InputSession.init(registry, router);

    try session.applyKey(.space, true, false);
    try session.applyMouseButton(.left, true, Vector2.xy(10.0, 20.0));

    try std.testing.expect(session.inputState().digitalDown(jump));
    try std.testing.expect(session.inputState().digitalDown(select));
    try std.testing.expect(session.inputState().isMouseButtonDown(.left));

    session.releaseAll();

    try std.testing.expect(!session.inputState().digitalDown(jump));
    try std.testing.expect(!session.inputState().digitalDown(select));
    try std.testing.expect(!session.inputState().isMouseButtonDown(.left));
}

test "input session routes mouse button actions and pointer events" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const select = try registry.addDigital(gameplay, "pointer.select");

    var map = ActionMap.init();
    try map.bindMouseButton(.left, select);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var session = InputSession.init(registry, router);

    try session.applyMouseButton(.left, true, Vector2.xy(32.0, 48.0));

    const named = session.namedFrame(gameplay);

    try std.testing.expect(try named.digitalDown("pointer.select"));
    try std.testing.expect(try named.hasActionPressed("pointer.select"));
    try std.testing.expectEqual(@as(f32, 32.0), session.inputState().mousePosition().x);
    try std.testing.expectEqual(@as(f32, 48.0), session.inputState().mousePosition().y);
}

test "input session records mouse motion and wheel events" {
    var session = InputSession.empty();

    session.applyMouseMotion(Vector2.xy(100.0, 120.0));
    session.applyMouseWheel(
        Vector2.xy(0.0, -1.0),
        Vector2.xy(100.0, 120.0),
    );

    try std.testing.expectEqual(@as(usize, 2), session.eventCount());
    try std.testing.expectEqual(@as(f32, 100.0), session.inputState().mousePosition().x);
    try std.testing.expectEqual(@as(f32, 120.0), session.inputState().mousePosition().y);
    try std.testing.expectEqual(@as(f32, 0.0), session.inputState().mouseWheel().x);
    try std.testing.expectEqual(@as(f32, -1.0), session.inputState().mouseWheel().y);

    const reader = session.reader();

    const moved = reader.firstMouseMoved() orelse return error.ExpectedMouseMoved;
    try std.testing.expectEqual(@as(f32, 100.0), moved.position.x);
    try std.testing.expectEqual(@as(f32, 120.0), moved.position.y);

    const scrolled = reader.firstMouseScrolled() orelse return error.ExpectedMouseScrolled;
    try std.testing.expectEqual(@as(f32, 0.0), scrolled.wheel.x);
    try std.testing.expectEqual(@as(f32, -1.0), scrolled.wheel.y);
}

test "input session manages maps by name" {
    var registry = ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const pause = try registry.addMap("pause");

    var gameplay_map = ActionMap.init();
    var pause_map = ActionMap.init();

    const jump = try registry.addDigital(gameplay, "player.jump");
    const confirm = try registry.addDigital(pause, "ui.confirm");

    try gameplay_map.bindDigitalKey(.space, jump);
    try pause_map.bindDigitalKey(.space, confirm);

    var router = InputRouter.init();
    try router.putMap(gameplay, gameplay_map);
    try router.putMap(pause, pause_map);

    var session = InputSession.init(registry, router);

    try session.pushMapByName("gameplay");
    try session.pushMapOptionsByName("pause", ActiveMapOptions.modal(100));

    try std.testing.expect(session.activeContext().canProcessMap(pause));
    try std.testing.expect(!session.activeContext().canProcessMap(gameplay));

    try std.testing.expect(try session.popMapByName("pause"));
    try std.testing.expect(session.activeContext().canProcessMap(gameplay));
}

test "input session reports unknown named maps" {
    var session = InputSession.empty();

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        session.pushMapByName("missing"),
    );

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        session.namedFrameByName("missing"),
    );
}
