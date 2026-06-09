# 09. Rendering

Yuki uses SDL3 for platform work and wgpu-native for graphics.

## Split

```text
SDL3
  window
  input
  gamepads
  audio device
  lifecycle

wgpu-native
  GPU device
  surface
  buffers
  textures
  shaders
  render/compute pipelines

Yuki
  render2d
  future render3d
  materials
  cameras
  sprites
  meshes
  UI renderer
```

SDL and wgpu-native should not leak into Luau APIs.

## Internal graphics layers

```text
src/gpu/wgpu      thin wrapper over wgpu-native
src/render2d      sprites, text, tilemaps, UI drawing
src/render3d      future meshes, materials, lights
```

`src/gpu` can be WebGPU-shaped. Higher layers should use Yuki concepts.

## 2D first

The first renderer should focus on:

- clear pass;
- texture upload;
- sprite batch;
- camera matrices;
- text;
- tilemaps;
- render targets;
- UI drawing.

## 3D later

Initial 3D scope:

- Camera3D;
- Transform3D;
- mesh rendering;
- materials;
- depth;
- lights;
- glTF import.

Future rendering research:

- PBR;
- compute-driven workflows;
- GPU culling;
- ray tracing experiments.

Ray tracing should be treated as research, not a baseline promise.
