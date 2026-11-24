{
  buildGoModule,
  fetchFromGitHub,
  lib,
  libnotify,
  quickshell,
  xdg-utils,
  packageUpdater,
}:
buildGoModule (finalAttrs: {
  pname = "dankmail";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "arqueon";
    repo = "dux-mail";
    rev = "v${finalAttrs.version}";
    hash = "sha256-BIqIiPPUszz6j19g9EcJfUGNjyN/c8r+2B001DvZBlk=";
  };

  # The upstream handler test's 1s deadline can expire during SQLite migration
  # under concurrent Nix builds; remove this patch once upstream fixes the test.
  postPatch = ''
    substituteInPlace core/cmd/dmail/handlers_quota_test.go \
      --replace-fail 'context.WithTimeout(context.Background(), time.Second)' \
        'context.WithTimeout(context.Background(), 10*time.Second)'
  '';

  # Attachment tests create files under $HOME, which the sandbox leaves unwritable.
  preCheck = ''
    export HOME="$TMPDIR"
  '';

  modRoot = "core";
  subPackages = [ "cmd/dmail" ];
  vendorHash = "sha256-JSURjt7trVE9Mi5lPGKcBFV0vZ7ewsRO2ccVN8NPC2c=";

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
    install -Dm644 "${finalAttrs.src}/assets/org.arqueon.duxmail.desktop" \
      "$out/share/applications/org.arqueon.duxmail.desktop"
    install -Dm644 "${finalAttrs.src}/quickshell/assets/duxmail.svg" \
      "$out/share/icons/hicolor/scalable/apps/duxmail.svg"

    install -d "$out/share/DankMaterialShell/plugins/dankmailUnread"
    cp -R "${finalAttrs.src}/dms-plugin/." \
      "$out/share/DankMaterialShell/plugins/dankmailUnread/"
  '';

  passthru.updateScript = packageUpdater.script {
    attr = "dankmail";
    file = ./default.nix;
    nixUpdateArgs = [ "--use-github-releases" ];
  };

  meta = {
    description = "Keyboard-driven local-first email triage for Linux";
    homepage = "https://github.com/arqueon/dux-mail";
    changelog = "https://github.com/arqueon/dux-mail/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "dmail";
    platforms = lib.platforms.linux;
  };
})
