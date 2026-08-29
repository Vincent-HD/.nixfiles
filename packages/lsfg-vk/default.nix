{
  lib,
  cmake,
  fetchgit,
  llvmPackages,
  ninja,
  qt6,
  vulkan-headers,
  writeShellScript,
  bun,
  gitMinimal,
  nix-prefetch-git,
}:

let
  updateScript = writeShellScript "update-lsfg-vk" ''
    export PATH="${
      lib.makeBinPath [
        bun
        gitMinimal
        nix-prefetch-git
      ]
    }:$PATH"
    exec ${bun}/bin/bun ${./update.ts} "$@"
  '';
in
llvmPackages.stdenv.mkDerivation (finalAttrs: {
  pname = "lsfg-vk";
  version = "2.0.0-rc1";

  src = fetchgit {
    url = "https://git.lsfg-vk.dev/lsfg-vk.git";
    rev = "f715073ee39377fbe2bd856db01b458b920b126e";
    hash = "sha256-+2Zslbt4A3opMsCgu3/BMA2PJm6vzIFwhsS9Iml9H3Y=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtdeclarative
    vulkan-headers
  ];

  strictDeps = true;

  cmakeFlags = [
    "-G Ninja"
    "-DLSFGVK_BUILD_LAYER=ON"
    "-DLSFGVK_BUILD_CLI=ON"
    "-DLSFGVK_BUILD_UI=ON"
    "-DLSFGVK_INSTALL_LIBRARIES=OFF"
    "-DLSFGVK_LAYER_MULTILIB_X86=OFF"
    "-DLSFGVK_MANAGED=ON"
    "-DLSFGVK_LAYER_LIBRARY_PATH=${placeholder "out"}/lib/liblsfg-vk-layer.so"
  ];

  meta = {
    description = "Lossless Scaling frame generation Vulkan layer, CLI, and Qt interface";
    homepage = "https://lsfg-vk.dev/";
    changelog = "https://git.lsfg-vk.dev/lsfg-vk/tag/${finalAttrs.version}";
    license = lib.licenses.cc-by-nc-nd-40;
    mainProgram = "lsfg-vk-ui";
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };

  passthru.updateScript = [ updateScript ];
})
