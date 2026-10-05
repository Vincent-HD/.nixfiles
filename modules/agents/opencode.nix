{ inputs, ... }:
{
  config.flake.modules.homeManager.agentOpencode =
    {
      pkgs,
      lib,
      ...
    }:
    let
      opencodePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencodev2;
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;

      # OpenCode V2 discovers the shared ~/.agents/skills directory automatically.
      # Allow those skills and the shared Executor MCP catalog without duplicating
      # the skill source in an explicit config entry.
      opencodeConfig = {
        "$schema" = "https://opencode.ai/config.json";
        mcp.servers.executor = {
          type = "local";
          command = [
            (lib.getExe executorPackage)
            "mcp"
          ];
        };
        permissions = [
          {
            action = "skill";
            resource = "*";
            effect = "allow";
          }
          {
            action = "execute";
            resource = "*";
            effect = "allow";
          }
          {
            action = "executor_*";
            resource = "*";
            effect = "allow";
          }
        ];
      };
    in
    {
      home.packages = [ opencodePackage ];

      xdg.configFile."opencode/opencode.json".source =
        (pkgs.formats.json { }).generate "opencode.json" opencodeConfig;
    };
}
