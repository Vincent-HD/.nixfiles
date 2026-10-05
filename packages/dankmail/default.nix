{
  buildGoModule,
  fetchFromGitHub,
  lib,
  libnotify,
  quickshell,
  xdg-utils,
}:
buildGoModule (finalAttrs: {
  pname = "dankmail";
  version = "0.3.11";

  src = fetchFromGitHub {
    owner = "arqueon";
    repo = "dankmail";
    rev = "v${finalAttrs.version}";
    hash = "sha256-PGGDxhC1Ykhg/YsSHHZ/40dq338epraIlPv6pzJaX10=";
  };

  # The upstream handler test's 1s deadline can expire during SQLite migration
  # under concurrent Nix builds; remove this patch once upstream fixes the test.
  postPatch = ''
    substituteInPlace core/cmd/dmail/handlers_quota_test.go \
      --replace-fail 'context.WithTimeout(context.Background(), time.Second)' \
        'context.WithTimeout(context.Background(), 10*time.Second)'
  '';

  modRoot = "core";
  subPackages = [ "cmd/dmail" ];
  vendorHash = "sha256-R5qlfcUqTmXaUThFule2tXRivUavnYVkzS8+Z4i8zt4=";

  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=v${finalAttrs.version}"
  ];

  propagatedBuildInputs = [
    libnotify
    quickshell
    xdg-utils
  ];

  postInstall = ''
    install -d "$out/share/quickshell/dankmail"
    cp -R "${finalAttrs.src}/quickshell/." "$out/share/quickshell/dankmail/"

    install -Dm644 "${finalAttrs.src}/LICENSE" "$out/share/licenses/dankmail/LICENSE"
    install -Dm644 "${finalAttrs.src}/assets/org.arqueon.dankmail.desktop" \
      "$out/share/applications/org.arqueon.dankmail.desktop"
    install -Dm644 "${finalAttrs.src}/quickshell/assets/dankmail.svg" \
      "$out/share/icons/hicolor/scalable/apps/dankmail.svg"

    install -d "$out/share/DankMaterialShell/plugins/dankmailUnread"
    cp -R "${finalAttrs.src}/dms-plugin/." \
      "$out/share/DankMaterialShell/plugins/dankmailUnread/"
  '';

  meta = {
    description = "Keyboard-driven local-first email triage for Linux";
    homepage = "https://github.com/arqueon/dankmail";
    changelog = "https://github.com/arqueon/dankmail/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "dmail";
    platforms = lib.platforms.linux;
  };
})
