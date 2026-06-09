{
  description = "Yuki Engine development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;

          isLinux = pkgs.stdenv.isLinux;
          isDarwin = pkgs.stdenv.isDarwin;

          # A merged Vulkan SDK-like path for tools that expect VULKAN_SDK.
          # wgpu-native can use Vulkan on Linux; validation/tools are useful while
          # building the renderer and debugging GPU issues.
          vulkanSdk = pkgs.symlinkJoin {
            name = "yuki-vulkan-sdk";
            paths =
              with pkgs;
              [
                vulkan-headers
                vulkan-loader
                vulkan-validation-layers
                vulkan-tools
                glslang
                spirv-tools
              ]
              ++ lib.optionals (pkgs ? shaderc) [ shaderc ];
          };

          sdlPackages =
            with pkgs;
            [ sdl3 ]
            ++ lib.optionals (pkgs ? SDL3_image) [ SDL3_image ]
            ++ lib.optionals (pkgs ? SDL3_ttf) [ SDL3_ttf ];

          commonPackages =
            with pkgs;
            [
              zig
              zls

              git
              pkg-config
              cmake
              ninja
              clang
              lld
            ]
            ++ lib.optionals (pkgs ? mold) [ mold ]
            ++ lib.optionals (pkgs ? luau) [ luau ]
            ++ lib.optionals (pkgs ? stylua) [ stylua ];

          # Included by default because Yuki may build wgpu-native from source in
          # engine-development mode. Normal game templates can later use prebuilt
          # static artifacts instead.
          rustPackages = with pkgs; [
            rustc
            cargo
            rustfmt
            clippy
          ];

          linuxPackages =
            with pkgs;
            lib.optionals isLinux (
              [
                vulkanSdk
                vulkan-loader
                vulkan-validation-layers
                vulkan-tools

                libGL
                libxkbcommon
                wayland
                wayland-protocols

                libx11
                libxcursor
                libxi
                libxrandr
                libxinerama
              ]
              ++ lib.optionals (pkgs ? renderdoc) [ renderdoc ]
            );

          darwinPackages =
            with pkgs;
            lib.optionals isDarwin [
              darwin.apple_sdk.frameworks.Cocoa
              darwin.apple_sdk.frameworks.Foundation
              darwin.apple_sdk.frameworks.GameController
              darwin.apple_sdk.frameworks.Metal
              darwin.apple_sdk.frameworks.MetalKit
              darwin.apple_sdk.frameworks.QuartzCore
            ];

          runtimeLibs =
            sdlPackages
            ++ lib.optionals isLinux (
              with pkgs;
              [
                vulkan-loader
                libGL
                libxkbcommon
                wayland
                libx11
                libxcursor
                libxi
                libxrandr
                libxinerama
              ]
            );

          basePackages = commonPackages ++ sdlPackages ++ linuxPackages ++ darwinPackages;

          mkYukiShell =
            {
              withRust ? true,
            }:
            pkgs.mkShell {
              packages = basePackages ++ lib.optionals withRust rustPackages;

              shellHook = ''
                export YUKI_ROOT="$PWD"
                export YUKI_LINK_MODE="static"
                export YUKI_RENDER_BACKEND="wgpu-native"
                export YUKI_PLATFORM_BACKEND="sdl3"

                export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-cache/local"
                export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-cache/global"
                mkdir -p "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR"
              ''
              + lib.optionalString isLinux ''

                export VULKAN_SDK="${vulkanSdk}"
                export VK_LAYER_PATH="${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d"
                export LD_LIBRARY_PATH="${lib.makeLibraryPath runtimeLibs}:$LD_LIBRARY_PATH"
              ''
              + ''

                echo "Welcome to Yuki Engine"
                echo "  Zig:        $(zig version 2>/dev/null || echo unavailable)"
                echo "  SDL3:       $(pkg-config --modversion sdl3 2>/dev/null || echo available)"
                echo "  Renderer:   wgpu-native"
                echo "  Link mode:  static-first"
                echo "  Studio:     native Yuki app (later)"
                echo ""
                echo "Useful commands:"
                echo "  zig build"
                echo "  zig build test"
              '';
            };
        in
        {
          # Full engine-development shell. Includes Rust/Cargo so wgpu-native can
          # be built from source while the renderer backend is still evolving.
          default = mkYukiShell { withRust = true; };

          # Lighter shell for users working only on Zig/Luau code while using
          # prebuilt wgpu-native artifacts.
          noRust = mkYukiShell { withRust = false; };
        }
      );
    };
}
