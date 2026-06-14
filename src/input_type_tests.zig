//! Input type tests.
//!
//! These tests cover the small shared declarations that other input modules
//! build on.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const input = yuki2d.input;

test "input action ids preserve compact indexes" {
    const digital = input.DigitalActionId.fromIndex(3);
    const axis1 = input.Axis1ActionId.fromIndex(4);
    const axis2 = input.Axis2ActionId.fromIndex(5);
    const map = input.ActionMapId.fromIndex(6);

    try std.testing.expectEqual(@as(u16, 3), digital.index);
    try std.testing.expectEqual(@as(u16, 4), axis1.index);
    try std.testing.expectEqual(@as(u16, 5), axis2.index);
    try std.testing.expectEqual(@as(u16, 6), map.index);
}

test "input action ref reports its kind" {
    const digital = input.DigitalActionId.fromIndex(0);
    const axis1 = input.Axis1ActionId.fromIndex(0);
    const axis2 = input.Axis2ActionId.fromIndex(0);

    try std.testing.expectEqual(input.ActionKind.digital, (input.ActionRef{ .digital = digital }).kind());
    try std.testing.expectEqual(input.ActionKind.axis1, (input.ActionRef{ .axis1 = axis1 }).kind());
    try std.testing.expectEqual(input.ActionKind.axis2, (input.ActionRef{ .axis2 = axis2 }).kind());
}

test "input map ids compare by index" {
    const first = input.ActionMapId.fromIndex(1);
    const same = input.ActionMapId.fromIndex(1);
    const other = input.ActionMapId.fromIndex(2);

    try std.testing.expect(first.eql(same));
    try std.testing.expect(!first.eql(other));
}

test "input type limits stay internally consistent" {
    try std.testing.expectEqual(input.max_digital_actions, input.max_actions);
    try std.testing.expectEqual(input.max_action_maps, input.max_active_action_maps);
    try std.testing.expect(input.max_bindings > 0);
    try std.testing.expect(input.max_input_events > 0);
}

test "keyboard and mouse sentinel values are last" {
    try std.testing.expect(@intFromEnum(input.Key.count) > @intFromEnum(input.Key.escape));
    try std.testing.expect(@intFromEnum(input.Key.count) > @intFromEnum(input.Key.f1));

    try std.testing.expect(@intFromEnum(input.MouseButton.count) > @intFromEnum(input.MouseButton.left));
    try std.testing.expect(@intFromEnum(input.MouseButton.count) > @intFromEnum(input.MouseButton.x2));
}
