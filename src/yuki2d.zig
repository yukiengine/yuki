//! Public Yuki2D API façade.
//!
//! Luau bindings should be modeled after this module instead of internal Zig
//! files. Internals can keep changing, while this file documents the API shape
//! we want game code to grow around.

/// Public 2D render data API.
pub const render = @import("render2d.zig");

/// Public input action and pointer state API.
pub const input = @import("input/mod.zig");

/// Public read-only input frame API.
pub const input_frame = @import("input/frame.zig");

/// Public 2D camera helpers.
pub const camera = @import("camera2d.zig");

/// Public 2D scene, prefab, actor, event, and picking API.
pub const scene = @import("scene2d.zig");

/// Public tilemap data and collision helper API.
pub const tilemap = @import("tilemap.zig");

/// Public texture asset catalog API.
pub const assets = @import("assets.zig");

/// Public debug drawing helpers.
pub const debug_draw = @import("debug_draw.zig");

/// Public time and frame pacing helpers.
pub const time = @import("time.zig");

/// Common 2D vector type.
pub const Vector2 = render.Vector2;

/// Common 2D rectangle type.
pub const Rect2D = render.Rect2D;

/// Common 2D transform type.
pub const Transform2D = render.Transform2D;

/// Common RGBA color type.
pub const ColorRgba = render.ColorRgba;

/// Common 2D camera type.
pub const Camera2D = render.Camera2D;

/// Common sprite handle data.
pub const Sprite = render.Sprite;

/// Common texture id handle.
pub const TextureId = render.TextureId;

/// Public scene type.
pub const Scene = scene.Scene;

/// Public actor handle.
pub const ActorId = scene.ActorId;

/// Public actor tag.
pub const ActorTag = scene.ActorTag;

/// Public prefab handle.
pub const PrefabId = scene.PrefabId;

/// Public actor prefab description.
pub const ActorPrefab = scene.ActorPrefab;

/// Public spawn override description.
pub const SpawnOverride = scene.SpawnOverride;

/// Public input action handle.
pub const ActionId = input.ActionId;

/// Public keyboard key enum.
pub const Key = input.Key;

/// Public mouse button enum.
pub const MouseButton = input.MouseButton;

/// Public input state.
pub const InputState = input.State;

/// Public input binding map.
pub const InputMap = input.InputMap;

/// Public read-only input frame.
pub const InputFrame = input_frame.Frame;

/// Public named input frame view.
pub const NamedInputFrame = input.NamedFrame;

/// Public frame-local input event iterator.
pub const InputEventIterator = input_frame.EventIterator;

/// Public frame-local input event.
pub const InputEvent = input.InputEvent;

/// Public owned input session.
pub const InputSession = input.InputSession;
