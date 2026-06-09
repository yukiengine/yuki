# 11. Yuki Studio

Yuki Studio is the future native editor.

Principle:

> Yuki is built with Yuki.

Studio should use the same runtime, renderer, UI system, asset pipeline, and Luau integration as games.

## Not first

The engine starts code-first.

Before Studio, Yuki needs:

- Yuki2D runtime;
- Luau scripting;
- assets;
- rendering;
- UI runtime;
- game standard library basics.

## Why native

A native Studio can share:

- renderer;
- input;
- UI;
- asset pipeline;
- play-in-editor runtime;
- profiling/debug tools;
- project model.

A web-first tool would be useful for some tasks, but it would not dogfood Yuki itself.

## Early Studio scope

First useful Studio features:

- project browser;
- asset browser;
- problem list;
- log console;
- sprite/animation preview;
- content inspectors;
- play/reload buttons.

Later:

- tilemap editor;
- prefab editor;
- dialogue graph;
- UI editor;
- save inspector;
- 3D scene editor.

## Build shape

Studio should live as an app target:

```text
apps/yuki-studio/
```

Studio-only code should not ship in exported games.
