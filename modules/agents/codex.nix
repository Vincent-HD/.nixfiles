{ inputs, ... }:
let
  mkCodexSettings =
    { pkgs, lib }:
    let
      plannotatorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.plannotator;
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;
    in
    {
      model = "gpt-5.5";
      # Disable all interactive approval prompts, leaving Auto-review with nothing to process.
      approval_policy = "never";
      # Keep sandbox-boundary approval prompts with the user instead of the Auto-review agent.
      approvals_reviewer = "user";
      model_reasoning_effort = "high";
      model_reasoning_summary = "concise";
      model_verbosity = "low";

      # Enable parallel subagent execution with the requested default model and effort.
      agents = {
        enabled = true;
        max_concurrent_threads_per_session = 100;
        default_subagent_model = "gpt-6-luna";
        default_subagent_reasoning_effort = "max";
      };
      file_opener = "cursor";
      personality = "pragmatic";

      # Plannotator uses Codex's Stop lifecycle hook for automatic plan review.
      features.hooks = true;
      hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = lib.getExe plannotatorPackage;
              timeout = 345600;
              statusMessage = "Reviewing plan in Plannotator";
            }
          ];
        }
      ];

      # Executor is the single local MCP endpoint; it owns the upstream catalog.
      mcp_servers = {
        executor = {
          command = lib.getExe executorPackage;
          args = [ "mcp" ];
          enabled = true;
        };
      };
    };

  mkCodexConfig =
    { pkgs, lib }:
    (pkgs.formats.toml { }).generate "codex-config.toml" (mkCodexSettings {
      pkgs = pkgs;
      lib = lib;
    });
in
{
  config.flake.modules.darwin.agentCodex =
    { pkgs, lib, ... }:
    {
      # Install the official Codex CLI; the codex-app cask is deprecated upstream.
      homebrew.casks = [
        "codex"
      ];

      # System-level Codex defaults shared by the CLI and IDE extension.
      environment.etc."codex/config.toml".source = mkCodexConfig {
        pkgs = pkgs;
        lib = lib;
      };

    };

  config.flake.modules.nixos.agentCodex =
    { pkgs, lib, ... }:
    {
      # System-level Codex defaults shared by the CLI and IDE extension.
      environment.etc."codex/config.toml".source = mkCodexConfig {
        pkgs = pkgs;
        lib = lib;
      };
    };

  config.flake.modules.homeManager.agentCodex =
    { pkgs, ... }:
    let
      # On Linux, use the pinned package from packages/codex. On macOS, OpenAI
      # publishes the official binary via the Homebrew cask installed by
      # darwin.agentCodex; reference it directly to avoid a second CLI installation.
      codexExec =
        if pkgs.stdenv.hostPlatform.isLinux then
          pkgs.lib.getExe (pkgs.callPackage ../../packages/codex { })
        else
          "/opt/homebrew/bin/codex";

      # Keep the selected Codex executable behind one user-facing wrapper.
      codex = pkgs.lib.hiPrio (
        pkgs.writeShellScriptBin "codex" ''
          set -euo pipefail

          exec ${codexExec} "$@"
        ''
      );

    in
    {
      config = {
        home.packages = [ codex ];

        home.file.".codex/.keep".text = "";
      };
    };
}
