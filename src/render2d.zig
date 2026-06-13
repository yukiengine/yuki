//! Public 2D rendering API.
//!
//! This module is the stable import point for code that wants to describe 2D
//! draw data. The wgpu-backed renderer implementation lives under
//! `render2d/renderer.zig`; game-facing code should usually import this file.

const types = @import("render2d/types.zig");

/// Maximum number of quads that can be submitted in one draw list.
pub const max_quads = types.max_quads;

/// Errors returned while building 2D draw lists.
pub const DrawError = types.DrawError;

/// Two-component vector used for positions, sizes, and directions.
pub const Vector2 = types.Vector2;

/// Axis-aligned rectangle in world or screen space.
pub const Rect2D = types.Rect2D;

/// Position, size, and rotation used to place a 2D sprite.
pub const Transform2D = types.Transform2D;

/// Linear RGBA color used by draw calls.
pub const ColorRgba = types.ColorRgba;

/// Normalized texture coordinate rectangle.
pub const UvRect = types.UvRect;

/// Handle for a texture stored by the renderer.
pub const TextureId = types.TextureId;

/// One renderable textured or solid-color quad.
pub const Quad = types.Quad;

/// Texture region and tint data used by sprites.
pub const Sprite = types.Sprite;

/// Camera used to transform world-space quads.
pub const Camera2D = types.Camera2D;

/// Immutable view of one prepared render frame.
pub const Frame = types.Frame;

/// Bounded list of draw commands for one frame.
pub const DrawList = types.DrawList;

/// Pixel-sized atlas helper for creating sprites and UVs.
pub const TextureAtlas = types.TextureAtlas;

/// Fixed-grid sprite animation description.
pub const SpriteAnimation = types.SpriteAnimation;

/// Runtime animation cursor for one sprite animation.
pub const AnimationPlayer = types.AnimationPlayer;
