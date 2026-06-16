//! Public Zig scripting module.
//!
//! This module is the Zig-side entry point for Luau hosting. It should expose
//! Yuki-owned scripting concepts, not raw Luau C API symbols.

const host_mod = @import("host.zig");

/// Runtime owner for one Luau VM.
pub const ScriptHost = host_mod.ScriptHost;

/// Loaded script module table pinned in the Luau registry.
pub const ScriptModule = host_mod.ScriptModule;

/// Script host construction and loading errors.
pub const ScriptHostError = host_mod.Error;

const context_mod = @import("context.zig");

/// Frame-local runtime systems passed to script callbacks.
pub const ScriptContext = context_mod.ScriptContext;

/// Script context runtime lookup errors.
pub const ScriptContextError = context_mod.Error;
