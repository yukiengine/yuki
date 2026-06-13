const std = @import("std");
const world2d = @import("world2d.zig");

/// Maximum tracked actor overlap pairs per frame.
pub const max_actor_overlaps = 64;

/// Errors returned by the actor overlap tracker.
pub const Error = error{
    ActorOverlapSetFull,
};

/// Stable pair describing one actor overlapping another actor.
pub const ActorOverlapPair = struct {
    actor: world2d.ActorId,
    other: world2d.ActorId,
    actor_tag: world2d.ActorTag,
    other_tag: world2d.ActorTag,

    /// Creates an actor overlap pair from two actors and their tags.
    pub fn init(
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) ActorOverlapPair {
        return .{
            .actor = actor,
            .other = other,
            .actor_tag = actor_tag,
            .other_tag = other_tag,
        };
    }

    /// Returns true when both handles identify the same overlap pair.
    pub fn eql(self: ActorOverlapPair, other: ActorOverlapPair) bool {
        return self.actor.eql(other.actor) and self.other.eql(other.other);
    }

    /// Returns true when this pair belongs to one actor and target tag query.
    pub fn matchesQuery(self: ActorOverlapPair, actor: world2d.ActorId, target_tag: world2d.ActorTag) bool {
        return self.actor.eql(actor) and self.other_tag.eql(target_tag);
    }
};

/// Bounded set of actor overlap pairs.
pub const ActorOverlapSet = struct {
    pairs: [max_actor_overlaps]ActorOverlapPair,
    pair_count: usize = 0,

    /// Creates an empty overlap set.
    pub fn init() ActorOverlapSet {
        return .{
            .pairs = undefined,
        };
    }

    /// Removes all stored pairs.
    pub fn clear(self: *ActorOverlapSet) void {
        self.pair_count = 0;
    }

    /// Returns stored overlap pairs.
    pub fn items(self: *const ActorOverlapSet) []const ActorOverlapPair {
        return self.pairs[0..self.pair_count];
    }

    /// Returns the number of stored overlap pairs.
    pub fn count(self: *const ActorOverlapSet) usize {
        return self.pair_count;
    }

    /// Returns true when the set has no pairs.
    pub fn isEmpty(self: *const ActorOverlapSet) bool {
        return self.pair_count == 0;
    }

    /// Returns true when an equal pair is already stored.
    pub fn contains(self: *const ActorOverlapSet, pair: ActorOverlapPair) bool {
        for (self.items()) |stored| {
            if (stored.eql(pair)) return true;
        }

        return false;
    }

    /// Adds one pair without checking for duplicates.
    pub fn add(self: *ActorOverlapSet, pair: ActorOverlapPair) !void {
        if (self.pair_count == max_actor_overlaps) {
            return Error.ActorOverlapSetFull;
        }

        self.pairs[self.pair_count] = pair;
        self.pair_count += 1;
    }

    /// Adds one pair only when it is not already stored.
    pub fn addUnique(self: *ActorOverlapSet, pair: ActorOverlapPair) !void {
        if (self.contains(pair)) return;
        try self.add(pair);
    }
};

/// Tracks previous and current actor overlaps to classify transitions.
pub const ActorOverlapTracker = struct {
    previous: ActorOverlapSet,
    current: ActorOverlapSet,

    /// Creates an empty overlap tracker.
    pub fn init() ActorOverlapTracker {
        return .{
            .previous = ActorOverlapSet.init(),
            .current = ActorOverlapSet.init(),
        };
    }

    /// Starts a new frame while keeping previous-frame overlap state.
    pub fn beginFrame(self: *ActorOverlapTracker) void {
        self.current.clear();
    }

    /// Commits current overlaps so the next frame can detect transitions.
    pub fn finishFrame(self: *ActorOverlapTracker) void {
        self.previous = self.current;
        self.current.clear();
    }

    /// Records one overlap in the current frame.
    pub fn remember(self: *ActorOverlapTracker, pair: ActorOverlapPair) !void {
        try self.current.addUnique(pair);
    }

    /// Returns true when the pair existed in the previous frame.
    pub fn wasOverlapping(self: *const ActorOverlapTracker, pair: ActorOverlapPair) bool {
        return self.previous.contains(pair);
    }

    /// Returns true when the pair exists in the current frame.
    pub fn isCurrent(self: *const ActorOverlapTracker, pair: ActorOverlapPair) bool {
        return self.current.contains(pair);
    }

    /// Returns previous-frame overlap pairs.
    pub fn previousItems(self: *const ActorOverlapTracker) []const ActorOverlapPair {
        return self.previous.items();
    }

    /// Returns current-frame overlap pairs.
    pub fn currentItems(self: *const ActorOverlapTracker) []const ActorOverlapPair {
        return self.current.items();
    }
};
