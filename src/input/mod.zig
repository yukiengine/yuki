// types.zig
const types = @import("types.zig");

pub const Vector2 = types.Vector2;

pub const max_action_maps = types.max_action_maps;
pub const max_active_action_maps = types.max_active_action_maps;
pub const max_digital_actions = types.max_digital_actions;
pub const max_axis1_actions = types.max_axis1_actions;
pub const max_axis2_actions = types.max_axis2_actions;
pub const max_bindings = types.max_bindings;
pub const max_actions = types.max_actions;
pub const max_input_events = types.max_input_events;

pub const Error = types.Error;

pub const DigitalActionId = types.DigitalActionId;
pub const ActionId = types.ActionId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;
pub const ActionMapId = types.ActionMapId;
pub const ActionKind = types.ActionKind;
pub const ActionRef = types.ActionRef;
pub const Key = types.Key;
pub const MouseButton = types.MouseButton;

// events.zig
const events_mod = @import("events.zig");

pub const InputSourceKind = events_mod.InputSourceKind;
pub const InputSource = events_mod.InputSource;
pub const InputEventKind = events_mod.InputEventKind;
pub const DigitalActionEvent = events_mod.DigitalActionEvent;
pub const Axis1ActionEvent = events_mod.Axis1ActionEvent;
pub const Axis2ActionEvent = events_mod.Axis2ActionEvent;
pub const MouseMotionEvent = events_mod.MouseMotionEvent;
pub const MouseButtonEvent = events_mod.MouseButtonEvent;
pub const MouseWheelEvent = events_mod.MouseWheelEvent;
pub const InputEvent = events_mod.InputEvent;
pub const InputEventQueue = events_mod.InputEventQueue;

// state.zig
const state_mod = @import("state.zig");

pub const DigitalState = state_mod.DigitalState;
pub const Axis1State = state_mod.Axis1State;
pub const Axis2State = state_mod.Axis2State;
pub const MouseButtonState = state_mod.MouseButtonState;
pub const MouseState = state_mod.MouseState;
pub const KeyState = state_mod.KeyState;
pub const ActionState = state_mod.ActionState;
pub const State = state_mod.State;

// context.zig
const context_mod = @import("context.zig");

pub const ActiveMapOptions = context_mod.ActiveMapOptions;
pub const ActiveActionMap = context_mod.ActiveActionMap;
pub const InputContext = context_mod.InputContext;

// action_map.zig
const action_map_mod = @import("action_map.zig");

pub const DigitalKeyBinding = action_map_mod.DigitalKeyBinding;
pub const Axis1KeyBinding = action_map_mod.Axis1KeyBinding;
pub const Axis2KeyBinding = action_map_mod.Axis2KeyBinding;
pub const Binding = action_map_mod.Binding;
pub const ActionMap = action_map_mod.ActionMap;
pub const InputMap = action_map_mod.InputMap;

// router.zig
const router_mod = @import("router.zig");

pub const StoredActionMap = router_mod.StoredActionMap;
pub const ActionMapSet = router_mod.ActionMapSet;
pub const InputRouter = router_mod.InputRouter;

// builder.zig
const builder_mod = @import("builder.zig");

pub const ActionMapBuilder = builder_mod.ActionMapBuilder;

// event_reader.zig
const event_reader_mod = @import("event_reader.zig");

pub const EventReader = event_reader_mod.EventReader;
pub const EventIterator = event_reader_mod.EventIterator;

// named_frame.zig
const named_frame_mod = @import("named_frame.zig");

pub const NamedFrame = named_frame_mod.NamedFrame;

// named_events.zig
const named_events_mod = @import("named_events.zig");

pub const NamedDigitalActionEvent = named_events_mod.NamedDigitalActionEvent;
pub const NamedAxis1ActionEvent = named_events_mod.NamedAxis1ActionEvent;
pub const NamedAxis2ActionEvent = named_events_mod.NamedAxis2ActionEvent;
pub const NamedInputEvent = named_events_mod.NamedInputEvent;
pub const NamedEventReader = named_events_mod.NamedEventReader;
pub const NamedEventIterator = named_events_mod.NamedEventIterator;

// session.zig
const session_mod = @import("session.zig");

pub const InputSession = session_mod.InputSession;

// session_builder.zig
const session_builder_mod = @import("session_builder.zig");

pub const InputSessionBuilder = session_builder_mod.InputSessionBuilder;

// registry.zig
const registry_mod = @import("registry.zig");

pub const NamedActionMap = registry_mod.NamedActionMap;
pub const NamedDigitalAction = registry_mod.NamedDigitalAction;
pub const NamedAxis1Action = registry_mod.NamedAxis1Action;
pub const NamedAxis2Action = registry_mod.NamedAxis2Action;
pub const ActionRegistry = registry_mod.ActionRegistry;
pub const ActionDescriptor = registry_mod.ActionDescriptor;

// source_names.zig
const source_names_mod = @import("source_names.zig");

pub const KeyName = source_names_mod.KeyName;
pub const MouseButtonName = source_names_mod.MouseButtonName;
pub const SourceControlName = source_names_mod.SourceControlName;

pub const key_names = source_names_mod.key_names;
pub const mouse_button_names = source_names_mod.mouse_button_names;

pub const keyName = source_names_mod.keyName;
pub const keyNameAssert = source_names_mod.keyNameAssert;
pub const findKey = source_names_mod.findKey;
pub const parseKey = source_names_mod.parseKey;
pub const isKeyName = source_names_mod.isKeyName;

pub const mouseButtonName = source_names_mod.mouseButtonName;
pub const mouseButtonNameAssert = source_names_mod.mouseButtonNameAssert;
pub const findMouseButton = source_names_mod.findMouseButton;
pub const parseMouseButton = source_names_mod.parseMouseButton;
pub const isMouseButtonName = source_names_mod.isMouseButtonName;

pub const sourceKindName = source_names_mod.sourceKindName;
pub const sourceControlName = source_names_mod.sourceControlName;
pub const sourceControlNameEql = source_names_mod.sourceControlNameEql;

// binding_descriptors.zig
const binding_descriptors_mod = @import("binding_descriptors.zig");

pub const NamedBindingKind = binding_descriptors_mod.NamedBindingKind;
pub const NamedDigitalKeyBinding = binding_descriptors_mod.NamedDigitalKeyBinding;
pub const NamedMouseButtonBinding = binding_descriptors_mod.NamedMouseButtonBinding;
pub const NamedAxis1KeyBinding = binding_descriptors_mod.NamedAxis1KeyBinding;
pub const NamedAxis2KeyBinding = binding_descriptors_mod.NamedAxis2KeyBinding;
pub const NamedBinding = binding_descriptors_mod.NamedBinding;
pub const NamedBindingReader = binding_descriptors_mod.NamedBindingReader;
pub const NamedBindingIterator = binding_descriptors_mod.NamedBindingIterator;

// named_context.zig
const named_context_mod = @import("named_context.zig");

pub const NamedActiveMap = named_context_mod.NamedActiveMap;
pub const NamedInputContext = named_context_mod.NamedInputContext;
pub const NamedActiveMapIterator = named_context_mod.NamedActiveMapIterator;
