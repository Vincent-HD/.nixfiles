{
  stdenv,
  buildPackages,
  v4l-utils,
  fetchFromGitHub,
  fetchpatch,
  meson,
  pkg-config,
  ninja,
  cmake,
  libxxf86vm,
  libxtst,
  libxres,
  libxrender,
  libxmu,
  libxi,
  libxext,
  libxdamage,
  libxcursor,
  libxcomposite,
  libx11,
  xwininfo,
  xprop,
  libxcb,
  libdrm,
  libei,
  vulkan-loader,
  vulkan-headers,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libxkbcommon,
  glm,
  gbenchmark,
  libcap,
  libavif,
  SDL2,
  pipewire,
  pixman,
  python3,
  libinput,
  glslang,
  hwdata,
  stb,
  wlroots_0_19,
  libdecor,
  lcms,
  lib,
  luajit,
  catch2_3,
  makeBinaryWrapper,
  writeShellScript,
  bun,
  gitMinimal,
  nix-prefetch-git,
  enableExecutable ? true,
  enableWsi ? false,
}:
let
  # Resolve the moving fork branch and recursively prefetch its submodules for nix-update.
  updateScript = writeShellScript "update-gamescope-lanczos" ''
    export PATH="${
      lib.makeBinPath [
        bun
        gitMinimal
        nix-prefetch-git
      ]
    }:$PATH"
    exec ${bun}/bin/bun ${./update.ts} "$@"
  '';

  # Keep the shader collection exposed by the nixpkgs Gamescope package.
  frogShaders = fetchFromGitHub {
    owner = "misyltoad";
    repo = "GamescopeShaders";
    rev = "v0.1";
    hash = "sha256-gR1AeAHV/Kn4ntiEDUSPxASLMFusV6hgSGrTbMCBUZA=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "gamescope-lanczos";
  version = "3.16.25-unstable-2026-08-16";

  src = fetchFromGitHub {
    owner = "ThomasEricB";
    repo = "gamescope-lanczos-downscaling";
    rev = "7494c483f3febabc4a1ce274222201b8f812af49";
    fetchSubmodules = true;
    hash = "sha256-N2CTButWJp7NakO7kQkjZRcAVrMhJ4Bdcj1I8s199Yw=";
  };

  patches = [
    # Required so ReShade can find the extra shader collection under $out/share/gamescope/reshade.
    ./shaders-path.patch
    # Harden watchdog startup for store-path launches or environments without $out/bin in PATH.
    # This is runtime-only and is not required to build.
    ./gamescopereaper.patch
    # Valve's compatibility patch is required with current nixpkgs's STB package:
    # it provides stb_image_resize2.h, not the legacy stb_image_resize.h.
    (fetchpatch {
      url = "https://github.com/ValveSoftware/gamescope/commit/d49a2aded261030e649fee42ad295f1ef56b736b.diff";
      hash = "sha256-Uh08ZRaV912ZOsl1DMpbVLxIgh4jEXevgihQf2W9KFk=";
    })
  ];

  postPatch = ''
    # Only ReShade uses GetUsrDir; scripts and looks already use the Meson install prefix.
    substituteInPlace src/Utils/DirHelpers.cpp --replace-fail "@out@" "$out"

    # The libdisplay-info helper is executed during the build.
    patchShebangs subprojects/libdisplay-info/tool/gen-search-table.py

    substituteInPlace src/Utils/Process.cpp --subst-var-by "gamescopereaper" "$out/bin/gamescopereaper"
    patchShebangs default_extras_install.sh
  '';

  mesonFlags = [
    (lib.mesonBool "enable_gamescope" enableExecutable)
    (lib.mesonBool "enable_gamescope_wsi_layer" enableWsi)
  ];

  # Do not install the vendored wlroots/vkroots projects.
  mesonInstallFlags = [ "--skip-subprojects" ];

  strictDeps = true;

  depsBuildBuild = [
    pkg-config
  ];

  nativeBuildInputs = [
    meson
    pkg-config
    ninja
    wayland-scanner
    cmake

    # Gamescope uses git describe to encode its version into the binary.
    (buildPackages.writeShellScriptBin "git" "echo ${finalAttrs.version}")
  ]
  ++ lib.optionals enableExecutable [
    makeBinaryWrapper
    glslang
    python3
    hwdata
    v4l-utils
  ];

  buildInputs = [
    glm
    pipewire
    stb
    hwdata
    libx11
    libxcb
    wayland
    wayland-protocols
    vulkan-headers
    vulkan-loader
    catch2_3
  ]
  ++ lib.optionals enableExecutable (
    wlroots_0_19.buildInputs
    ++ [
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxi
      libxmu
      libxrender
      libxres
      libxtst
      libxxf86vm
      libavif
      libdrm
      libei
      SDL2
      libdecor
      libinput
      libxkbcommon
      gbenchmark
      pixman
      libcap
      lcms
      luajit
    ]
  );

  postInstall = lib.optionalString enableExecutable ''
    # Stable patchelf can corrupt the binary on this package.
    ${lib.getExe buildPackages.patchelfUnstable} $out/bin/gamescope \
      --add-rpath ${vulkan-loader}/lib --add-needed libvulkan.so.1

    # --debug-layers expects these utilities in PATH.
    wrapProgram "$out/bin/gamescope" \
      --prefix PATH : ${
        lib.makeBinPath [
          xprop
          xwininfo
        ]
      }

    # Preserve the ReShade shader collection provided by nixpkgs Gamescope.
    mkdir -p "$out/share/gamescope/reshade"
    cp -r ${frogShaders}/* "$out/share/gamescope/reshade/"
  '';

  meta = {
    description = "Gamescope with Lanczos downscaling and NVIDIA fixes";
    homepage = "https://github.com/ThomasEricB/gamescope-lanczos-downscaling";
    license = [
      lib.licenses.bsd2
      lib.licenses.lgpl21Plus
      lib.licenses.lgpl3Plus
    ];
    mainProgram = "gamescope";
    platforms = lib.platforms.linux;
  };

  # Let the repository updater refresh the moving fork without changing build inputs or patches.
  passthru.updateScript = [ updateScript ];
})
