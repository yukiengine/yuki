//! Input context active map tests.
//!
//! These tests cover priority, modal blocking, and map activation behavior
//! before runtime input dispatch starts using multiple maps.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMapId = input.ActionMapId;
const ActiveMapOptions = input.ActiveMapOptions;
const Error = input.Error;
const InputContext = input.InputContext;
const max_active_action_maps = input.max_active_action_maps;

test "input context starts empty" {
    const context = InputContext.init();

    try std.testing.expect(context.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), context.count());
    try std.testing.expect(context.top() == null);
    try std.testing.expectEqual(@as(usize, 0), context.processedItems().len);
}

test "input context pushes a default active map" {
    const gameplay = ActionMapId.fromIndex(0);

    var context = InputContext.init();
    try context.pushMap(gameplay);

    try std.testing.expect(!context.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), context.count());
    try std.testing.expect(context.containsMap(gameplay));
    try std.testing.expect(context.canProcessMap(gameplay));

    const top = context.top() orelse return error.ExpectedActiveMap;
    try std.testing.expect(top.hasMap(gameplay));
    try std.testing.expectEqual(@as(i16, 0), top.priority);
    try std.testing.expect(!top.blocking);
}

test "input context orders higher priority maps first" {
    const gameplay = ActionMapId.fromIndex(0);
    const debug = ActionMapId.fromIndex(1);
    const ui = ActionMapId.fromIndex(2);

    var context = InputContext.init();
    try context.pushMapOptions(gameplay, .{ .priority = 0 });
    try context.pushMapOptions(debug, .{ .priority = 50 });
    try context.pushMapOptions(ui, .{ .priority = 100 });

    const items = context.items();

    try std.testing.expect(items[0].hasMap(ui));
    try std.testing.expect(items[1].hasMap(debug));
    try std.testing.expect(items[2].hasMap(gameplay));
}

test "input context orders newer maps first at the same priority" {
    const gameplay = ActionMapId.fromIndex(0);
    const debug = ActionMapId.fromIndex(1);
    const overlay = ActionMapId.fromIndex(2);

    var context = InputContext.init();
    try context.pushMapOptions(gameplay, .{ .priority = 10 });
    try context.pushMapOptions(debug, .{ .priority = 10 });
    try context.pushMapOptions(overlay, .{ .priority = 10 });

    const items = context.items();

    try std.testing.expect(items[0].hasMap(overlay));
    try std.testing.expect(items[1].hasMap(debug));
    try std.testing.expect(items[2].hasMap(gameplay));
}

test "input context updates existing maps instead of duplicating them" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);

    var context = InputContext.init();
    try context.pushMapOptions(gameplay, .{ .priority = 0 });
    try context.pushMapOptions(ui, .{ .priority = 10 });
    try context.pushMapOptions(gameplay, .{ .priority = 100, .blocking = true });

    try std.testing.expectEqual(@as(usize, 2), context.count());

    const items = context.items();
    try std.testing.expect(items[0].hasMap(gameplay));
    try std.testing.expectEqual(@as(i16, 100), items[0].priority);
    try std.testing.expect(items[0].blocking);
}

test "input context pops active maps" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);

    var context = InputContext.init();
    try context.pushMap(gameplay);
    try context.pushMap(ui);

    try std.testing.expect(context.popMap(gameplay));
    try std.testing.expect(!context.containsMap(gameplay));
    try std.testing.expect(context.containsMap(ui));
    try std.testing.expectEqual(@as(usize, 1), context.count());

    try std.testing.expect(!context.popMap(gameplay));
}

test "input context blocking map hides lower priority maps" {
    const gameplay = ActionMapId.fromIndex(0);
    const pause_menu = ActionMapId.fromIndex(1);
    const debug = ActionMapId.fromIndex(2);

    var context = InputContext.init();
    try context.pushMapOptions(gameplay, .{ .priority = 0 });
    try context.pushMapOptions(pause_menu, ActiveMapOptions.modal(100));
    try context.pushMapOptions(debug, .{ .priority = 200 });

    const processed = context.processedItems();

    try std.testing.expectEqual(@as(usize, 2), processed.len);
    try std.testing.expect(processed[0].hasMap(debug));
    try std.testing.expect(processed[1].hasMap(pause_menu));
    try std.testing.expect(context.canProcessMap(debug));
    try std.testing.expect(context.canProcessMap(pause_menu));
    try std.testing.expect(!context.canProcessMap(gameplay));
}

test "input context clear removes all active maps" {
    const gameplay = ActionMapId.fromIndex(0);

    var context = InputContext.init();
    try context.pushMap(gameplay);

    context.clear();

    try std.testing.expect(context.isEmpty());
    try std.testing.expect(!context.containsMap(gameplay));
    try std.testing.expectEqual(@as(usize, 0), context.processedItems().len);
}

test "input context can update maps while at full capacity" {
    var context = InputContext.init();

    var index: usize = 0;
    while (index < max_active_action_maps) : (index += 1) {
        try context.pushMap(ActionMapId.fromIndex(@intCast(index)));
    }

    const existing = ActionMapId.fromIndex(0);
    try context.pushMapOptions(existing, .{ .priority = 99, .blocking = true });

    try std.testing.expectEqual(@as(usize, max_active_action_maps), context.count());

    const top = context.top() orelse return error.ExpectedActiveMap;
    try std.testing.expect(top.hasMap(existing));
    try std.testing.expect(top.blocking);
}
