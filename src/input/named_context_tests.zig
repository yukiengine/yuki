//! Named active input context tests.
//!
//! These tests verify that active map routing state can be inspected by stable
//! map names without exposing raw ActionMapId values to future API layers.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

test "named input context describes active maps" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    var context = input.InputContext.init();
    try context.pushMap(gameplay);
    try context.pushMapOptions(ui, input.ActiveMapOptions.modal(100));

    const named = input.NamedInputContext.init(&registry, &context);

    try std.testing.expectEqual(@as(usize, 2), named.count());
    try std.testing.expectEqual(@as(usize, 1), named.processedCount());
    try std.testing.expect(named.containsMapName("gameplay"));
    try std.testing.expect(named.containsMapName("ui"));
    try std.testing.expect(!named.containsMapName("missing"));

    try std.testing.expect(!named.canProcessMapName("gameplay"));
    try std.testing.expect(named.canProcessMapName("ui"));
}

test "named input context returns top and blocking maps" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const pause = try registry.addMap("pause");

    var context = input.InputContext.init();
    try context.pushMap(gameplay);
    try context.pushMapOptions(pause, input.ActiveMapOptions.modal(50));

    const named = input.NamedInputContext.init(&registry, &context);

    const top = named.top() orelse return error.ExpectedTopMap;
    try std.testing.expect(top.map.eql(pause));
    try std.testing.expect(top.isBlocking());
    try std.testing.expect(top.canProcess());
    try std.testing.expectEqualStrings("pause", top.map_name);

    const blocking = named.firstBlocking() orelse return error.ExpectedBlockingMap;
    try std.testing.expect(blocking.map.eql(pause));
    try std.testing.expectEqualStrings("pause", blocking.map_name);
}

test "named input context iterates active maps in routing order" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");
    const overlay = try registry.addMap("overlay");

    var context = input.InputContext.init();
    try context.pushMap(gameplay);
    try context.pushMap(ui);
    try context.pushMapOptions(overlay, .{ .priority = 10 });

    const named = input.NamedInputContext.init(&registry, &context);
    var iterator = named.iter();

    const first = iterator.next() orelse return error.ExpectedActiveMap;
    try std.testing.expect(first.map.eql(overlay));
    try std.testing.expectEqualStrings("overlay", first.map_name);

    const second = iterator.next() orelse return error.ExpectedActiveMap;
    try std.testing.expect(second.map.eql(ui));
    try std.testing.expectEqualStrings("ui", second.map_name);

    const third = iterator.next() orelse return error.ExpectedActiveMap;
    try std.testing.expect(third.map.eql(gameplay));
    try std.testing.expectEqualStrings("gameplay", third.map_name);

    try std.testing.expect(iterator.next() == null);
}

test "named input context iterates only processable maps" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const pause = try registry.addMap("pause");
    const overlay = try registry.addMap("overlay");

    var context = input.InputContext.init();
    try context.pushMap(gameplay);
    try context.pushMapOptions(pause, input.ActiveMapOptions.modal(50));
    try context.pushMapOptions(overlay, .{ .priority = 100 });

    const named = input.NamedInputContext.init(&registry, &context);
    var iterator = named.processedIter();

    const first = iterator.next() orelse return error.ExpectedActiveMap;
    try std.testing.expectEqualStrings("overlay", first.map_name);
    try std.testing.expect(first.canProcess());

    const second = iterator.next() orelse return error.ExpectedActiveMap;
    try std.testing.expectEqualStrings("pause", second.map_name);
    try std.testing.expect(second.canProcess());
    try std.testing.expect(second.isBlocking());

    try std.testing.expect(iterator.next() == null);
    try std.testing.expect(!named.canProcessMapName("gameplay"));
}

test "named input context finds maps by name" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    var context = input.InputContext.init();
    try context.pushMap(gameplay);
    try context.pushMapOptions(ui, .{ .priority = 20 });

    const named = input.NamedInputContext.init(&registry, &context);

    const gameplay_entry = named.findMapName("gameplay") orelse return error.ExpectedActiveMap;
    const ui_entry = named.findMapName("ui") orelse return error.ExpectedActiveMap;

    try std.testing.expect(gameplay_entry.map.eql(gameplay));
    try std.testing.expect(ui_entry.map.eql(ui));
    try std.testing.expectEqual(@as(i16, 20), ui_entry.priority);
    try std.testing.expect(named.findMapName("missing") == null);
}

test "input session exposes named active context" {
    var builder = input.InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addMap("pause");

    try builder.activateMap("gameplay");
    try builder.activateMapOptions("pause", input.ActiveMapOptions.modal(100));

    var session = try builder.build();
    const named = session.namedActiveContext();

    try std.testing.expect(named.containsMapName("gameplay"));
    try std.testing.expect(named.containsMapName("pause"));
    try std.testing.expect(!named.canProcessMapName("gameplay"));
    try std.testing.expect(named.canProcessMapName("pause"));

    const top = named.top() orelse return error.ExpectedTopMap;
    try std.testing.expectEqualStrings("pause", top.map_name);

    const popped = try session.popMapByName("pause");
    try std.testing.expect(popped);

    const after_pop = session.namedActiveContext();
    try std.testing.expect(after_pop.canProcessMapName("gameplay"));
    try std.testing.expect(!after_pop.containsMapName("pause"));
}
