//! Active input map context.
//!
//! This module owns the active action-map stack used by the input router. It
//! decides which maps are visible to input processing, how priority is ordered,
//! and where modal/blocking maps stop traversal.

const types = @import("types.zig");

pub const ActionMapId = types.ActionMapId;
pub const Error = types.Error;
pub const max_active_action_maps = types.max_active_action_maps;

/// Options used when enabling an action map in an input context.
pub const ActiveMapOptions = struct {
    priority: i16 = 0,
    blocking: bool = false,

    /// Creates default non-blocking map options.
    pub fn normal() ActiveMapOptions {
        return .{};
    }

    /// Creates blocking map options for modal UI-like input.
    pub fn modal(priority: i16) ActiveMapOptions {
        return .{
            .priority = priority,
            .blocking = true,
        };
    }
};

/// One active action map entry inside an input context.
pub const ActiveActionMap = struct {
    map: ActionMapId,
    priority: i16,
    blocking: bool,
    order: usize,

    /// Creates an active map entry.
    pub fn init(map: ActionMapId, options: ActiveMapOptions, order: usize) ActiveActionMap {
        return .{
            .map = map,
            .priority = options.priority,
            .blocking = options.blocking,
            .order = order,
        };
    }

    /// Returns true when this entry refers to the map.
    pub fn hasMap(self: ActiveActionMap, map: ActionMapId) bool {
        return self.map.eql(map);
    }
};

/// Runtime input context that controls which action maps are active.
pub const InputContext = struct {
    active_maps: [max_active_action_maps]ActiveActionMap,
    active_map_count: usize,
    next_order: usize,

    /// Creates an empty input context.
    pub fn init() InputContext {
        return .{
            .active_maps = undefined,
            .active_map_count = 0,
            .next_order = 0,
        };
    }

    /// Removes all active maps.
    pub fn clear(self: *InputContext) void {
        self.active_map_count = 0;
        self.next_order = 0;
    }

    /// Returns the number of active maps.
    pub fn count(self: *const InputContext) usize {
        return self.active_map_count;
    }

    /// Returns true when no maps are active.
    pub fn isEmpty(self: *const InputContext) bool {
        return self.active_map_count == 0;
    }

    /// Enables a map with default non-blocking options.
    pub fn pushMap(self: *InputContext, map: ActionMapId) !void {
        try self.pushMapOptions(map, .{});
    }

    /// Enables a map with explicit priority and blocking options.
    pub fn pushMapOptions(
        self: *InputContext,
        map: ActionMapId,
        options: ActiveMapOptions,
    ) !void {
        if (self.indexOfMap(map)) |existing_index| {
            self.active_maps[existing_index] = ActiveActionMap.init(
                map,
                options,
                self.claimOrder(),
            );
            self.sortActiveMaps();
            return;
        }

        if (self.active_map_count == max_active_action_maps) {
            return Error.InputContextFull;
        }

        self.active_maps[self.active_map_count] = ActiveActionMap.init(
            map,
            options,
            self.claimOrder(),
        );
        self.active_map_count += 1;
        self.sortActiveMaps();
    }

    /// Disables a map and returns true when it was active.
    pub fn popMap(self: *InputContext, map: ActionMapId) bool {
        const index = self.indexOfMap(map) orelse return false;

        var cursor = index;
        while (cursor + 1 < self.active_map_count) : (cursor += 1) {
            self.active_maps[cursor] = self.active_maps[cursor + 1];
        }

        self.active_map_count -= 1;
        return true;
    }

    /// Returns true when a map is active.
    pub fn containsMap(self: *const InputContext, map: ActionMapId) bool {
        return self.indexOfMap(map) != null;
    }

    /// Returns the active entry for a map.
    pub fn findMap(self: *const InputContext, map: ActionMapId) ?ActiveActionMap {
        const index = self.indexOfMap(map) orelse return null;
        return self.active_maps[index];
    }

    /// Returns active maps ordered by priority and activation order.
    pub fn items(self: *const InputContext) []const ActiveActionMap {
        return self.active_maps[0..self.active_map_count];
    }

    /// Returns the highest-priority active map.
    pub fn top(self: *const InputContext) ?ActiveActionMap {
        if (self.active_map_count == 0) return null;
        return self.active_maps[0];
    }

    /// Returns the active maps that should be processed before blocking stops traversal.
    pub fn processedItems(self: *const InputContext) []const ActiveActionMap {
        return self.active_maps[0..self.processedCount()];
    }

    /// Returns true when this map is active and not hidden behind a higher map.
    pub fn canProcessMap(self: *const InputContext, map: ActionMapId) bool {
        for (self.processedItems()) |entry| {
            if (entry.hasMap(map)) return true;
        }

        return false;
    }

    /// Returns the number of maps visible to input processing.
    fn processedCount(self: *const InputContext) usize {
        var total: usize = 0;

        for (self.items()) |entry| {
            total += 1;
            if (entry.blocking) break;
        }

        return total;
    }

    /// Returns the index of an active map.
    fn indexOfMap(self: *const InputContext, map: ActionMapId) ?usize {
        var index: usize = 0;
        while (index < self.active_map_count) : (index += 1) {
            if (self.active_maps[index].hasMap(map)) return index;
        }

        return null;
    }

    /// Returns the next activation order number.
    fn claimOrder(self: *InputContext) usize {
        const order = self.next_order;
        self.next_order += 1;
        return order;
    }

    /// Sorts maps so higher priority and newer equal-priority maps come first.
    fn sortActiveMaps(self: *InputContext) void {
        var index: usize = 1;
        while (index < self.active_map_count) : (index += 1) {
            const entry = self.active_maps[index];
            var cursor = index;

            while (cursor > 0 and activeMapComesBefore(entry, self.active_maps[cursor - 1])) {
                self.active_maps[cursor] = self.active_maps[cursor - 1];
                cursor -= 1;
            }

            self.active_maps[cursor] = entry;
        }
    }
};

/// Returns true when lhs should be processed before rhs.
fn activeMapComesBefore(lhs: ActiveActionMap, rhs: ActiveActionMap) bool {
    if (lhs.priority != rhs.priority) {
        return lhs.priority > rhs.priority;
    }

    return lhs.order > rhs.order;
}
