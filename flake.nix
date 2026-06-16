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

          # Luau's nixpkgs package currently installs the CLI tools only.
          # Yuki also needs headers and static libraries so Zig can host the VM.
          luauNative =
            if pkgs ? luau then
              pkgs.luau.overrideAttrs (old: {
                pname = "luau-native";

                installPhase = ''
                  runHook preInstall

                  mkdir -p $out/bin
                  mkdir -p $out/lib
                  mkdir -p $out/include

                  install -Dm755 -t $out/bin luau
                  install -Dm755 -t $out/bin luau-analyze
                  install -Dm755 -t $out/bin luau-compile

                  # if [ -f libLuau.VM.a ]; then
                  #   install -Dm644 libLuau.VM.a $out/lib/libLuau.VM.a
                  # fi
                  #
                  # if [ -f libLuau.Compiler.a ]; then
                  #   install -Dm644 libLuau.Compiler.a $out/lib/libLuau.Compiler.a
                  # fi
                  #
                  # if [ -f libLuau.Ast.a ]; then
                  #   install -Dm644 libLuau.Ast.a $out/lib/libLuau.Ast.a
                  # fi
                  #
                  # if [ -f libLuau.Config.a ]; then
                  #   install -Dm644 libLuau.Config.a $out/lib/libLuau.Config.a
                  # fi

                  for archive in libLuau*.a; do
                    if [ -f "$archive" ]; then
                      install -Dm644 "$archive" "$out/lib/$archive"
                    fi
                  done

                  copy_headers() {
                    cp -R "$1"/. $out/include/
                    chmod -R u+w $out/include
                  }

                  for include_dir in Common Ast Bytecode Compiler Config Analysis CodeGen VM Require; do
                    if [ -d "${old.src}/$include_dir/include" ]; then
                      copy_headers "${old.src}/$include_dir/include"
                    fi
                  done

                  chmod -R a+rX $out/include

                  runHook postInstall
                '';
              })
            else
              throw "This nixpkgs revision does not provide luau";

          cxxRuntimeLib = lib.getLib pkgs.stdenv.cc.cc;

          # Zig's normal build path still needs the exact libstdc++.so after
          # Luau's static archives; -lstdc++ alone leaves C++ symbols unresolved.
          luauCxxLib =
            if isDarwin then "-lc++" else "-L${cxxRuntimeLib}/lib -Wl,-rpath,${cxxRuntimeLib}/lib -lstdc++";

          # Local pkg-config shim so build.zig can link Luau like SDL3/wgpu-native.
          luauPkgConfig = pkgs.writeTextDir "lib/pkgconfig/luau.pc" ''
            prefix=${luauNative}
            includedir=${luauNative}/include
            libdir=${luauNative}/lib

            Name: Luau
            Description: Luau VM libraries for Yuki scripting
            Version: ${pkgs.luau.version}
            Cflags: -I${luauNative}/include
            Libs: -L${luauNative}/lib -Wl,-rpath,${luauNative}/lib -Wl,--start-group -lLuau.Compiler -lLuau.Bytecode -lLuau.Ast -lLuau.VM -lLuau.Common -Wl,--end-group ${luauCxxLib}
          '';

          luauPackages = [
            luauNative
            luauPkgConfig
          ];

          wgpuNativeDev = lib.getDev pkgs.wgpu-native;
          wgpuNativeLib = lib.getLib pkgs.wgpu-native;

          # nixpkgs' wgpu-native package ships headers and libwgpu_native.so,
          # but no pkg-config file. Keep this shim local so build.zig can link
          # it the same way it links SDL3.
          wgpuNativePkgConfig = pkgs.writeTextDir "lib/pkgconfig/wgpu_native.pc" ''
            prefix=${wgpuNativeLib}
            includedir=${wgpuNativeDev}/include
            libdir=${wgpuNativeLib}/lib

            Name: wgpu-native
            Description: Native WebGPU implementation based on wgpu-core
            Version: ${pkgs.wgpu-native.version}
            Cflags: -I${wgpuNativeDev}/include
            Libs: -L${wgpuNativeLib}/lib -Wl,-rpath,${wgpuNativeLib}/lib -lwgpu_native
          '';

          wgpuPackages = [
            wgpuNativeDev
            wgpuNativeLib
            wgpuNativePkgConfig
          ];

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
            ++ [
              wgpuNativeLib
              luauNative
            ]
            ++ lib.optionals (!isDarwin) [ pkgs.stdenv.cc.cc.lib ]
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

          basePackages =
            commonPackages ++ sdlPackages ++ wgpuPackages ++ luauPackages ++ linuxPackages ++ darwinPackages;

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
                export YUKI_STDCXX_LIB="${cxxRuntimeLib}/lib/libstdc++.so"

                export PKG_CONFIG_PATH="${wgpuNativePkgConfig}/lib/pkgconfig:${luauPkgConfig}/lib/pkgconfig:$PKG_CONFIG_PATH"

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
                echo "  wgpu-native: $(pkg-config --modversion wgpu_native 2>/dev/null || echo available)"
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
