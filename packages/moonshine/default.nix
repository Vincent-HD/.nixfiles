{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libdrm,
  libevdev,
  libgbm,
  libglvnd,
  libopus,
  libpulseaudio,
  libxkbcommon,
  vulkan-loader,
  wayland,
  zstd,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "moonshine";
  version = "0.14.5";

  # Use the upstream x86_64 Linux release instead of compiling Moonshine's Rust workspace.
  src = fetchurl {
    url = "https://github.com/hgaiser/moonshine/releases/download/v${finalAttrs.version}/moonshine-v${finalAttrs.version}-linux-amd64.tar.zst";
    hash = "sha256-FS9XqzqaMYpDGginjSl+7njB6Smb1ITDoku2gn6BFEE=";
  };

  sourceRoot = "moonshine";

  nativeBuildInputs = [
    autoPatchelfHook
    zstd
  ];

  # The binary opens EGL and Vulkan with dlopen, so ask autoPatchelfHook to
  # preserve both Nix's dispatch libraries and NixOS's active GPU driver path.
  appendRunpaths = [
    "/run/opengl-driver/lib"
    (lib.makeLibraryPath [ libglvnd vulkan-loader ])
  ];

  # The release is dynamically linked against these libraries. The Vulkan loader,
  # GLVND, and the NVIDIA driver path are also added above for libraries opened with dlopen.
  buildInputs = [
    libdrm
    libevdev
    libgbm
    libglvnd
    libopus
    libpulseaudio
    stdenv.cc.cc.lib
    libxkbcommon
    vulkan-loader
    wayland
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/moonshine "$out/bin/moonshine"
    install -Dm755 lib/moonshine/vulkan-layers/libmoonshine_wsi.so \
      "$out/lib/moonshine/vulkan-layers/libmoonshine_wsi.so"

    # Point the implicit-layer manifest at the immutable Nix store path.
    install -Dm644 share/moonshine/VkLayer_moonshine_wsi.json \
      "$out/share/vulkan/implicit_layer.d/VkLayer_moonshine_wsi.json"
    substituteInPlace "$out/share/vulkan/implicit_layer.d/VkLayer_moonshine_wsi.json" \
      --replace-fail \
        /usr/lib/moonshine/vulkan-layers/libmoonshine_wsi.so \
        "$out/lib/moonshine/vulkan-layers/libmoonshine_wsi.so"

    # Install the host integration files consumed by the NixOS module.
    install -Dm644 share/moonshine/60-moonshine.rules \
      "$out/lib/udev/rules.d/60-moonshine.rules"
    install -Dm644 share/moonshine/50-moonshine-inhibit-sleep.rules \
      "$out/share/polkit-1/rules.d/50-moonshine-inhibit-sleep.rules"
    install -Dm644 share/moonshine/moonshine-modules.conf \
      "$out/lib/modules-load.d/moonshine.conf"
    install -Dm644 share/moonshine/moonshine-sysusers.conf \
      "$out/lib/sysusers.d/moonshine.conf"
    install -Dm644 LICENSE "$out/share/licenses/moonshine/LICENSE"

    runHook postInstall
  '';

  meta = {
    description = "Headless streaming server for Moonlight clients";
    homepage = "https://github.com/hgaiser/moonshine";
    license = lib.licenses.bsd2;
    mainProgram = "moonshine";
    platforms = [ "x86_64-linux" ];
  };
})
