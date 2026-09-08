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
  buildCli ? true,
  buildUi ? true,
  multilib ? false,
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
  version = "2.0.0";

  src = fetchgit {
    url = "https://git.lsfg-vk.dev/lsfg-vk.git";
    rev = "2333707d55b68ddd8066fd95404c3b7d07e00d3a";
    hash = "sha256-vp0/adJdVV73C2RFjcEE90KjWiZJQhiqqOlYQ89RG+Y=";
  };

  nativeBuildInputs = [
    cmake
    ninja
  ]
  ++ lib.optionals buildUi [ qt6.wrapQtAppsHook ];

  buildInputs = [ vulkan-headers ] ++ lib.optionals buildUi [ qt6.qtdeclarative ];

  strictDeps = true;

  cmakeFlags = [
    "-G Ninja"
    "-DLSFGVK_BUILD_LAYER=ON"
    "-DLSFGVK_BUILD_CLI=${if buildCli then "ON" else "OFF"}"
    "-DLSFGVK_BUILD_UI=${if buildUi then "ON" else "OFF"}"
    "-DLSFGVK_INSTALL_LIBRARIES=OFF"
    "-DLSFGVK_LAYER_MULTILIB_X86=${if multilib then "ON" else "OFF"}"
    "-DLSFGVK_MANAGED=ON"
    "-DLSFGVK_LAYER_LIBRARY_PATH=${placeholder "out"}/lib/liblsfg-vk-layer${
      if multilib then ".x86" else ""
    }.so"
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
