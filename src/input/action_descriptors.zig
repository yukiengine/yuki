//! Named input action descriptors.
//!
//! Runtime systems should keep using compact typed action handles, but tools,
//! debug views, generated docs, and future Luau bindings need to inspect the
//! author-facing action list for one map.
//!
//! This module provides a read-only map-scoped reader over ActionRegistry. It
//! does not own registry data and does not mutate input routing.

const std = @import("std");
const types = @import("types.zig");
const registry_mod = @import("registry.zig");

/// Shared input error set.
pub const Error = types.Error;

/// Handle to a named action map.
pub const ActionMapId = types.ActionMapId;

/// Kind tag for a registered action.
pub const ActionKind = types.ActionKind;

/// Type-safe reference to any registered action handle.
pub const ActionRef = types.ActionRef;

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a 1D axis action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a 2D axis action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Named action registry.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// Named map metadata.
pub const NamedActionMap = registry_mod.NamedActionMap;

/// Named digital action metadata.
pub const NamedDigitalAction = registry_mod.NamedDigitalAction;

/// Named 1D axis action metadata.
pub const NamedAxis1Action = registry_mod.NamedAxis1Action;

/// Named 2D axis action metadata.
pub const NamedAxis2Action = registry_mod.NamedAxis2Action;

/// Descriptor for any named action.
pub const ActionDescriptor = registry_mod.ActionDescriptor;

/// Iterator phase for kind-grouped action iteration.
pub const NamedActionIteratorStage = enum(u8) {
    digital,
    axis1,
    axis2,
    done,
};

/// Read-only action descriptor view for one action map.
pub const NamedActionReader = struct {
    registry: *const ActionRegistry,
    map: ActionMapId,

    /// Creates a reader for actions belonging to one map.
    pub fn init(registry: *const ActionRegistry, map: ActionMapId) NamedActionReader {
        return .{
            .registry = registry,
            .map = map,
        };
    }

    /// Returns the map handle this reader describes.
    pub fn mapId(self: NamedActionReader) ActionMapId {
        return self.map;
    }

    /// Returns the stable map name for this reader.
    pub fn mapName(self: NamedActionReader) ![]const u8 {
        return self.registry.mapName(self.map) orelse Error.UnknownActionMap;
    }

    /// Returns the number of actions registered in this map.
    pub fn count(self: NamedActionReader) usize {
        return self.digitalCount() + self.axis1Count() + self.axis2Count();
    }

    /// Returns true when this map has no registered actions.
    pub fn isEmpty(self: NamedActionReader) bool {
        return self.count() == 0;
    }

    /// Returns the number of digital actions registered in this map.
    pub fn digitalCount(self: NamedActionReader) usize {
        var result: usize = 0;

        for (self.registry.digitalItems()) |item| {
            if (item.map.eql(self.map)) result += 1;
        }

        return result;
    }

    /// Returns the number of 1D axis actions registered in this map.
    pub fn axis1Count(self: NamedActionReader) usize {
        var result: usize = 0;

        for (self.registry.axis1Items()) |item| {
            if (item.map.eql(self.map)) result += 1;
        }

        return result;
    }

    /// Returns the number of 2D axis actions registered in this map.
    pub fn axis2Count(self: NamedActionReader) usize {
        var result: usize = 0;

        for (self.registry.axis2Items()) |item| {
            if (item.map.eql(self.map)) result += 1;
        }

        return result;
    }

    /// Returns an iterator over actions grouped by action kind.
    pub fn iter(self: NamedActionReader) NamedActionIterator {
        return NamedActionIterator.init(self);
    }

    /// Returns the first action descriptor in this map.
    pub fn first(self: NamedActionReader) ?ActionDescriptor {
        var iterator = self.iter();
        return iterator.next();
    }

    /// Finds an action descriptor by name inside this map.
    pub fn find(self: NamedActionReader, action_name: []const u8) ?ActionDescriptor {
        const action = self.registry.findAction(self.map, action_name) orelse return null;
        return self.registry.actionInfo(action);
    }

    /// Returns true when this map contains an action name.
    pub fn contains(self: NamedActionReader, action_name: []const u8) bool {
        return self.find(action_name) != null;
    }

    /// Returns the kind for a named action in this map.
    pub fn kindOf(self: NamedActionReader, action_name: []const u8) !ActionKind {
        const action = self.find(action_name) orelse return Error.UnknownActionName;
        return action.kind();
    }

    /// Returns the typed action reference for a named action in this map.
    pub fn actionRef(self: NamedActionReader, action_name: []const u8) !ActionRef {
        const action = self.find(action_name) orelse return Error.UnknownActionName;
        return action.actionRef();
    }
};

/// Forward-only iterator over named actions in one map.
pub const NamedActionIterator = struct {
    reader: NamedActionReader,
    stage: NamedActionIteratorStage,
    index: usize,

    /// Creates an action iterator starting at digital actions.
    pub fn init(reader: NamedActionReader) NamedActionIterator {
        return .{
            .reader = reader,
            .stage = .digital,
            .index = 0,
        };
    }

    /// Returns the next action descriptor, grouped digital, axis1, then axis2.
    pub fn next(self: *NamedActionIterator) ?ActionDescriptor {
        while (true) {
            switch (self.stage) {
                .digital => {
                    if (self.nextDigital()) |item| return .{ .digital = item };
                    self.advance(.axis1);
                },
                .axis1 => {
                    if (self.nextAxis1()) |item| return .{ .axis1 = item };
                    self.advance(.axis2);
                },
                .axis2 => {
                    if (self.nextAxis2()) |item| return .{ .axis2 = item };
                    self.advance(.done);
                },
                .done => return null,
            }
        }
    }

    /// Restarts iteration from the first action.
    pub fn reset(self: *NamedActionIterator) void {
        self.stage = .digital;
        self.index = 0;
    }

    /// Advances to another action kind group.
    fn advance(self: *NamedActionIterator, stage: NamedActionIteratorStage) void {
        self.stage = stage;
        self.index = 0;
    }

    /// Returns the next digital action for this reader's map.
    fn nextDigital(self: *NamedActionIterator) ?NamedDigitalAction {
        const items = self.reader.registry.digitalItems();

        while (self.index < items.len) {
            const item = items[self.index];
            self.index += 1;

            if (item.map.eql(self.reader.map)) return item;
        }

        return null;
    }

    /// Returns the next 1D axis action for this reader's map.
    fn nextAxis1(self: *NamedActionIterator) ?NamedAxis1Action {
        const items = self.reader.registry.axis1Items();

        while (self.index < items.len) {
            const item = items[self.index];
            self.index += 1;

            if (item.map.eql(self.reader.map)) return item;
        }

        return null;
    }

    /// Returns the next 2D axis action for this reader's map.
    fn nextAxis2(self: *NamedActionIterator) ?NamedAxis2Action {
        const items = self.reader.registry.axis2Items();

        while (self.index < items.len) {
            const item = items[self.index];
            self.index += 1;

            if (item.map.eql(self.reader.map)) return item;
        }

        return null;
    }
};
