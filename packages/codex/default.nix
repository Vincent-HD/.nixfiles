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
  version = "0.150.1";

  # Use the full package archive: CLI + required codex-code-mode-host sibling.
  # The plain `codex-*-linux-musl.tar.gz` asset only contains the CLI binary, which
  # breaks tool execution since 0.144 (hard fail on 0.147 with code_mode_host).
  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-AKunBPAp9twNlIvkB6dW4Ml8yEATL9aRNTssawpQWxc=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/codex "$out/bin/codex"
    install -Dm755 bin/codex-code-mode-host "$out/bin/codex-code-mode-host"
    wrapProgram "$out/bin/codex" \
      --set CODEX_CODE_MODE_HOST_PATH "$out/bin/codex-code-mode-host" \
      --prefix PATH : ${
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
