# 06. Yuki2D

Yuki2D is the first real product target.

It should become a strong 2D runtime/library before the engine grows into broader tooling or 3D.

## Scope

Yuki2D should provide:

- window/app lifecycle through SDL3;
- 2D rendering through wgpu-native;
- textures and sprites;
- sprite batching;
- Camera2D;
- text rendering;
- tilemap rendering;
- render targets;
- animation clips;
- audio playback;
- input actions;
- Luau scripting;
- asset loading;
- hot reload where practical;
- release packaging.

## First demo

The first useful demo should be tiny:

- one player sprite;
- keyboard/gamepad movement;
- camera follow;
- one tilemap;
- one sound;
- one Luau script;
- packaged release.

## Later 2D systems

After the base works:

- animation controller;
- particles;
- 2D collision helpers;
- Box2D-backed physics module;
- tilemap tools;
- UI integration;
- debug draw.

## Non-goals at this stage

- full native editor;
- 3D renderer;
- visual scripting;
- marketplace/package ecosystem;
- complete game standard library.
