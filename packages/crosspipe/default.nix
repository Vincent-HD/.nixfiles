{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  vala,
  gtk4,
  libadwaita,
  libgee,
  pipewire,
  libxml2,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "crosspipe";
  version = "0-unstable-2026-02-05";
  name = "${finalAttrs.pname}-${finalAttrs.version}";

  # Track upstream main through an exact commit so the package stays reproducible;
  # the update registry resolves the next main-branch commit when requested.
  src = fetchFromGitHub {
    owner = "pinpox";
    repo = "Crosspipe";
    rev = "43c626119f0c2fd2a0eabf9f0698f43bf467cb3d";
    hash = "sha256-vzR8/hW8QhbNYMP2XQOQFnKd0kHhIOJrlQ+KtXT9F50=";
  };

  nativeBuildInputs = [
    meson
    ninja
    vala
    pkg-config
  ];

  buildInputs = [
    gtk4
    libadwaita
    libgee
    pipewire
    libxml2
  ];

  strictDeps = true;

  meta = {
    description = "PipeWire graph GTK4/Libadwaita GUI with PR 11 auto-layout changes";
    homepage = "https://github.com/dp0sk/Crosspipe";
    license = lib.licenses.gpl3Only;
    mainProgram = "crosspipe";
    platforms = lib.platforms.linux;
  };
})
