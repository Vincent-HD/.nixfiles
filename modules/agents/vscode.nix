{ inputs, ... }:
{
  config.flake.modules.homeManager.agentVscode =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;
      vscodeSettingsPath =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json"
        else
          "${config.xdg.configHome}/Code/User/settings.json";

      vscodeAgentSettings = {
        "chat.useAgentSkills" = true;
        "chat.agentSkillsLocations" = {
          "~/.agents/skills" = true;
        };
        "chat.useAgentsMdFile" = true;
      };
      vscodeAgentSettingsFile =
        (pkgs.formats.json { }).generate "vscode-agent-settings.json"
          vscodeAgentSettings;

      # VS Code's user-profile mcp.json uses the standard stdio server schema.
      vscodeMcpServers = {
        executor = {
          type = "stdio";
          command = lib.getExe executorPackage;
          args = [ "mcp" ];
        };
      };
    in
    {
      # Keep the VS Code binary in codingEditors; this module owns its agent setup.
      programs.vscode = {
        enable = true;
        package = null;
        profiles.default = {
          extensions = [
            pkgs.vscode-extensions.github.copilot
            pkgs.vscode-extensions.github.copilot-chat
          ];

          # Home Manager writes this to VS Code's user profile on Linux and macOS.
          userMcp = {
            servers = vscodeMcpServers;
          };
        };
      };

      # Home Manager's userSettings option replaces the complete file. Use the
      # existing pinned jq package as a small two-file JSON merger so preferences
      # edited inside VS Code survive activation.
      home.activation.vscodeAgentSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings_path=${lib.escapeShellArg vscodeSettingsPath}
        settings_directory=${lib.escapeShellArg (builtins.dirOf vscodeSettingsPath)}
        mkdir -p "$settings_directory"

        if [ -f "$settings_path" ]; then
          if ! ${lib.getExe pkgs.jq} empty "$settings_path" > /dev/null; then
            printf 'VS Code settings are not valid JSON: %s\n' "$settings_path" >&2
            exit 1
          fi
        else
          printf '{}\n' > "$settings_path"
        fi

        settings_tmp="$(${pkgs.coreutils}/bin/mktemp "$settings_path.XXXXXX")"
        trap '${pkgs.coreutils}/bin/rm -f "$settings_tmp"' EXIT
        ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$settings_path" "${vscodeAgentSettingsFile}" > "$settings_tmp"
        ${pkgs.coreutils}/bin/mv "$settings_tmp" "$settings_path"
        trap - EXIT
      '';
    };
}
