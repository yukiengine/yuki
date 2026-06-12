const std = @import("std");
const c = @import("backend/sdl_c.zig").c;

pub const nanoseconds_per_second: u64 = 1_000_000_000;

pub const Duration = struct {
    nanoseconds: u64,

    pub fn zero() Duration {
        return .{ .nanoseconds = 0 };
    }

    pub fn fromNanoseconds(nanoseconds: u64) Duration {
        return .{ .nanoseconds = nanoseconds };
    }

    pub fn fromSeconds(seconds_value: f64) Duration {
        std.debug.assert(seconds_value >= 0.0);

        return .{
            .nanoseconds = @intFromFloat(seconds_value * @as(f64, @floatFromInt(nanoseconds_per_second))),
        };
    }

    pub fn seconds(self: Duration) f64 {
        return @as(f64, @floatFromInt(self.nanoseconds)) / @as(f64, @floatFromInt(nanoseconds_per_second));
    }

    pub fn seconds32(self: Duration) f32 {
        return @floatCast(self.seconds());
    }

    pub fn milliseconds(self: Duration) f64 {
        return self.seconds() * 1000.0;
    }

    pub fn add(self: Duration, other: Duration) Duration {
        return .{ .nanoseconds = self.nanoseconds + other.nanoseconds };
    }

    pub fn subtractSaturating(self: Duration, other: Duration) Duration {
        if (self.nanoseconds <= other.nanoseconds) return Duration.zero();

        return .{ .nanoseconds = self.nanoseconds - other.nanoseconds };
    }

    pub fn min(self: Duration, other: Duration) Duration {
        return if (self.nanoseconds <= other.nanoseconds) self else other;
    }

    pub fn max(self: Duration, other: Duration) Duration {
        return if (self.nanoseconds >= other.nanoseconds) self else other;
    }
};

pub const FrameInfo = struct {
    index: u64,
    started_at_ns: u64,
    delta: Duration,
    total: Duration,
};

pub const FrameClock = struct {
    last_frame_ns: u64,
    total_elapsed: Duration,
    frame_index: u64,

    pub fn init() FrameClock {
        return .{
            .last_frame_ns = nowNanoseconds(),
            .total_elapsed = Duration.zero(),
            .frame_index = 0,
        };
    }

    pub fn tick(self: *FrameClock) FrameInfo {
        const now = nowNanoseconds();
        const delta_ns = elapsedNanoseconds(self.last_frame_ns, now);
        const delta = Duration.fromNanoseconds(delta_ns);

        self.last_frame_ns = now;
        self.total_elapsed = self.total_elapsed.add(delta);
        self.frame_index += 1;

        return .{
            .index = self.frame_index,
            .started_at_ns = now,
            .delta = delta,
            .total = self.total_elapsed,
        };
    }
};

pub const FrameLimiter = struct {
    target_frame_time: Duration,
    enabled: bool = true,

    pub fn fps(target_fps: u32) FrameLimiter {
        std.debug.assert(target_fps > 0);

        return .{
            .target_frame_time = Duration.fromNanoseconds(nanoseconds_per_second /
                target_fps),
        };
    }

    pub fn disabled() FrameLimiter {
        return .{
            .target_frame_time = Duration.zero(),
            .enabled = false,
        };
    }

    pub fn wait(self: FrameLimiter, frame_started_at_ns: u64) void {
        if (!self.enabled) return;

        const now = nowNanoseconds();
        const elapsed = Duration.fromNanoseconds(elapsedNanoseconds(frame_started_at_ns, now));

        if (elapsed.nanoseconds >= self.target_frame_time.nanoseconds) return;

        const remaining = self.target_frame_time.subtractSaturating(elapsed);
        c.SDL_DelayNS(remaining.nanoseconds);
    }
};

pub const FpsCounter = struct {
    report_interval: Duration,
    accumulated: Duration,
    frames: u32,
    last_fps: f64,
    last_average_frame_time: Duration,

    pub fn init(report_interval: Duration) FpsCounter {
        std.debug.assert(report_interval.nanoseconds > 0);

        return .{
            .report_interval = report_interval,
            .accumulated = Duration.zero(),
            .frames = 0,
            .last_fps = 0.0,
            .last_average_frame_time = Duration.zero(),
        };
    }

    pub fn update(self: *FpsCounter, delta: Duration) bool {
        self.accumulated = self.accumulated.add(delta);
        self.frames += 1;

        if (self.accumulated.nanoseconds < self.report_interval.nanoseconds) {
            return false;
        }

        const elapsed_seconds = self.accumulated.seconds();
        self.last_fps = @as(f64, @floatFromInt(self.frames)) / elapsed_seconds;
        self.last_average_frame_time = Duration.fromNanoseconds(self.accumulated.nanoseconds / self.frames);

        self.accumulated = Duration.zero();
        self.frames = 0;

        return true;
    }

    pub fn fps(self: FpsCounter) f64 {
        return self.last_fps;
    }

    pub fn averageFrameTime(self: FpsCounter) Duration {
        return self.last_average_frame_time;
    }
};

pub fn nowNanoseconds() u64 {
    const counter = c.SDL_GetPerformanceCounter();
    const frequency = c.SDL_GetPerformanceFrequency();

    if (frequency == 0) return 0;

    const nanoseconds = (@as(u128, counter) * @as(u128, nanoseconds_per_second)) / @as(u128, frequency);

    return @intCast(nanoseconds);
}

fn elapsedNanoseconds(start_ns: u64, end_ns: u64) u64 {
    if (end_ns <= start_ns) return 0;

    return end_ns - start_ns;
}
