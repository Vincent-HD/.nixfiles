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

stdenv.mkDerivation {
  pname = "crosspipe";
  version = "0.1.1-pr11-unstable-2026-03-12";

  src = fetchFromGitHub {
    owner = "pinpox";
    repo = "Crosspipe";
    rev = "4625c101e31fece886d43348a22bd5eab1816f93";
    hash = "sha256-idDpGzeyJn4seoN9aIQ6Xon66rAwUjMYrqH2B4USDBI=";
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
}
