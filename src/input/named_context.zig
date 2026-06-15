//! Named active input context reader.
//!
//! InputContext stores compact ActionMapId entries ordered by priority and
//! modal/blocking rules. That is correct for routing input, but API-facing code
//! should inspect active maps by stable names.
//!
//! This module is a read-only bridge from active map handles to author-facing
//! names. It does not change routing behavior.

const std = @import("std");
const types = @import("types.zig");
const registry_mod = @import("registry.zig");
const context_mod = @import("context.zig");

/// Handle to a registered action map.
pub const ActionMapId = types.ActionMapId;

/// Named action registry used to resolve map handles.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// Runtime active input context.
pub const InputContext = context_mod.InputContext;

/// Runtime active map entry.
pub const ActiveActionMap = context_mod.ActiveActionMap;

/// Named description of one active action map.
pub const NamedActiveMap = struct {
    map: ActionMapId,
    map_name: []const u8,
    priority: i16,
    blocking: bool,
    order: usize,
    processed: bool,

    /// Returns true when this active map blocks lower-priority maps.
    pub fn isBlocking(self: NamedActiveMap) bool {
        return self.blocking;
    }

    /// Returns true when this active map receives input this frame.
    pub fn canProcess(self: NamedActiveMap) bool {
        return self.processed;
    }

    /// Returns true when this entry describes the provided map name.
    pub fn hasName(self: NamedActiveMap, name: []const u8) bool {
        return std.mem.eql(u8, self.map_name, name);
    }
};

/// Read-only name-based view of an active input context.
pub const NamedInputContext = struct {
    registry: *const ActionRegistry,
    context: *const InputContext,

    /// Creates a named view over an active input context.
    pub fn init(
        registry: *const ActionRegistry,
        context: *const InputContext,
    ) NamedInputContext {
        return .{
            .registry = registry,
            .context = context,
        };
    }

    /// Returns the number of active maps, including maps hidden behind modals.
    pub fn count(self: NamedInputContext) usize {
        return self.context.count();
    }

    /// Returns the number of maps that can process input.
    pub fn processedCount(self: NamedInputContext) usize {
        return self.context.processedItems().len;
    }

    /// Returns true when no maps are active.
    pub fn isEmpty(self: NamedInputContext) bool {
        return self.context.isEmpty();
    }

    /// Returns a named iterator over all active maps.
    pub fn iter(self: NamedInputContext) NamedActiveMapIterator {
        return NamedActiveMapIterator.init(self, false);
    }

    /// Returns a named iterator over maps that can process input.
    pub fn processedIter(self: NamedInputContext) NamedActiveMapIterator {
        return NamedActiveMapIterator.init(self, true);
    }

    /// Describes one active map entry.
    pub fn describe(self: NamedInputContext, active: ActiveActionMap) ?NamedActiveMap {
        const map_name = self.registry.mapName(active.map) orelse return null;

        return .{
            .map = active.map,
            .map_name = map_name,
            .priority = active.priority,
            .blocking = active.blocking,
            .order = active.order,
            .processed = self.context.canProcessMap(active.map),
        };
    }

    /// Returns the highest-priority active map.
    pub fn top(self: NamedInputContext) ?NamedActiveMap {
        const active = self.context.top() orelse return null;
        return self.describe(active);
    }

    /// Returns the first blocking active map, if any.
    pub fn firstBlocking(self: NamedInputContext) ?NamedActiveMap {
        var iterator = self.iter();

        while (iterator.next()) |active| {
            if (active.blocking) return active;
        }

        return null;
    }

    /// Finds an active map by stable map name.
    pub fn findMapName(self: NamedInputContext, map_name: []const u8) ?NamedActiveMap {
        var iterator = self.iter();

        while (iterator.next()) |active| {
            if (active.hasName(map_name)) return active;
        }

        return null;
    }

    /// Returns true when a map name is currently active.
    pub fn containsMapName(self: NamedInputContext, map_name: []const u8) bool {
        return self.findMapName(map_name) != null;
    }

    /// Returns true when a map name can process input this frame.
    pub fn canProcessMapName(self: NamedInputContext, map_name: []const u8) bool {
        const map = self.registry.findMap(map_name) orelse return false;
        return self.context.canProcessMap(map);
    }
};

/// Forward-only iterator over named active map entries.
pub const NamedActiveMapIterator = struct {
    reader: NamedInputContext,
    processed_only: bool,
    index: usize,

    /// Creates an iterator for all active maps or only processable maps.
    pub fn init(reader: NamedInputContext, processed_only: bool) NamedActiveMapIterator {
        return .{
            .reader = reader,
            .processed_only = processed_only,
            .index = 0,
        };
    }

    /// Returns the next named active map, skipping entries missing registry names.
    pub fn next(self: *NamedActiveMapIterator) ?NamedActiveMap {
        const items = if (self.processed_only)
            self.reader.context.processedItems()
        else
            self.reader.context.items();

        while (self.index < items.len) {
            const active = items[self.index];
            self.index += 1;

            if (self.reader.describe(active)) |named| return named;
        }

        return null;
    }

    /// Restarts iteration from the first active map.
    pub fn reset(self: *NamedActiveMapIterator) void {
        self.index = 0;
    }
};
