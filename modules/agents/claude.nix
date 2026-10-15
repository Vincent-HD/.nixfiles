{ inputs, ... }:
{
  config.flake.modules.homeManager.agentClaude =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;
      # Match the common agent setup's test-free RTK build on Darwin.
      rtk = pkgs.rtk.overrideAttrs (_previousAttrs: {
        doCheck = false;
      });
      projectSkills = pkgs.writeShellApplication {
        name = "claude-project-skills";
        runtimeInputs = [
          pkgs.jq
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnused
        ];
        text = builtins.readFile ./assets/claude-project-skills.sh;
      };
    in
    {
      # Use Claude's native integration while keeping shared sources authoritative.
      programs.claude-code = {
        enable = true;
        mutableSettings = true;
        context = "@${config.home.homeDirectory}/AGENTS.md";
        skills = config.custom.agentSetup.skills;
        settings = {
          pluginConfigs."cc-plugin-agents-md@builtin".options.instructionFiles = "claude-md-and-agents-md";
          hooks.PreToolUse = [
            {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "${lib.getExe rtk} hook claude";
                }
              ];
            }
          ];
          hooks.UserPromptSubmit = [
            {
              hooks = [
                {
                  type = "command";
                  command = lib.getExe projectSkills;
                }
              ];
            }
          ];
        };
        mcpServers.executor = {
          type = "stdio";
          command = lib.getExe executorPackage;
          args = [ "mcp" ];
        };
      };
    };
}
