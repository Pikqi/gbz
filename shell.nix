{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    zig_0_16
    pkg-config

    # OpenGL / GLX
    libGL
    mesa

    # Vulkan
    vulkan-loader
    vulkan-headers
    shaderc

    # X11
    xorg.libX11
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXi
    xorg.libXext

    # Wayland
    wayland
    libxkbcommon

    # Audio
    alsa-lib
  ];

  LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
    libGL
    mesa
    vulkan-loader
    xorg.libX11
    wayland
  ];
}
