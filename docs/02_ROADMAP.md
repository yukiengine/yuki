# 02. Roadmap

This roadmap is intentionally directional. It should change as the engine becomes real.

## Phase 0 — Project skeleton

Goal: create the minimum buildable engine workspace.

Deliverables:

- Zig project layout.
- Nix development shell.
- SDL3 linked.
- wgpu-native linked.
- Luau linked.
- Empty window.
- Clear color render pass.
- CLI command stub.

Exit condition: `zig build run` opens a window and renders a frame.

## Phase 1 — Yuki2D foundation

Goal: render a small scripted 2D scene.

Deliverables:

- SDL3 app lifecycle.
- wgpu-native device/surface setup.
- Basic GPU wrapper.
- Texture loading path.
- Sprite batch.
- Camera2D.
- Luau VM host.
- Luau script update loop.
- Basic input actions.

Exit condition: a Luau script moves a textured sprite on screen.

## Phase 2 — Complete Yuki2D core

Goal: make Yuki2D useful as a standalone 2D library/runtime.

Deliverables:

- Sprites, textures, render targets.
- Text rendering.
- Tilemap rendering.
- Animation clips.
- Audio playback.
- Asset registry and handles.
- Basic world/entity/prefab model.
- Hot reload for Luau and simple assets.
- Basic packaging.

Exit condition: a small 2D game can be made without custom engine code.

## Phase 3 — Game standard library

Goal: add reusable game systems.

First modules:

- scenes/state stack;
- saves;
- inventory/items;
- dialogue;
- localization;
- tilemaps/maps;
- UI runtime basics;
- animation controller;
- input actions.

Exit condition: a tiny top-down RPG template exists.

## Phase 4 — Yuki UI runtime

Goal: build the UI system that games and Studio will both use.

Deliverables:

- layout primitives;
- widgets;
- text styles;
- focus/navigation;
- themes;
- editor-friendly property controls;
- Luau UI API.

Exit condition: game menus and simple editor panels can be built with Yuki UI.

## Phase 5 — Native Yuki Studio

Goal: start the native editor after the runtime can support it.

Yuki Studio should be a Yuki app. No web-first editor path.

Early tools:

- project browser;
- asset browser;
- problem list;
- log console;
- content inspectors;
- sprite/animation preview;
- play/reload controls.

Exit condition: Studio can inspect and edit real Yuki project data.

## Phase 6 — 2D product hardening

Goal: turn the 2D engine into something reliable.

Work:

- docs;
- examples;
- tests;
- profiling;
- better errors;
- packaging polish;
- API cleanup;
- sample games.

Exit condition: Yuki2D can be recommended for small 2D projects.

## Phase 7 — 3D engine core

Goal: add 3D without destabilizing 2D.

Initial scope:

- Transform3D;
- Camera3D;
- mesh rendering;
- materials;
- depth pass;
- lights;
- glTF import;
- debug drawing.

Future research:

- PBR pipeline;
- compute workflows;
- GPU-driven rendering;
- ray tracing experiments behind optional feature gates.

Exit condition: a simple 3D scene runs from Luau.

## Phase 8 — Advanced modules and extensions

Goal: open the engine for larger games and custom systems.

Possible work:

- Zig native extension SDK;
- AI utilities;
- quests;
- combat helpers;
- procedural maps;
- 2D physics;
- 3D physics;
- advanced Studio panels.
