{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  makeWrapper,
  ripgrep,
  bubblewrap,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.146.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-W6O5QFVDlTCB9mHQhU0mb3biq75R1BNJNVo23nZzd2o=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 codex-x86_64-unknown-linux-musl "$out/bin/codex"
    wrapProgram "$out/bin/codex" --prefix PATH : ${
      lib.makeBinPath [
        ripgrep
        bubblewrap
      ]
    }

    runHook postInstall
  '';

  postInstall = ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = [ "x86_64-linux" ];
  };
})
