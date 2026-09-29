{ inputs, ... }:
{
  # Home Manager: Bitwarden desktop with its SSH agent, shared by both hosts.
  #
  # Only Linux pins the agent socket. Its path is predictable there, while macOS
  # keeps the agent configuration the application manages itself. The Linux value
  # is derived from the Home Manager home directory rather than a hardcoded
  # `/home/<user>` path so the module can be composed on Darwin too.
  config.flake.modules.homeManager.bitwarden =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # This list declares item names and destinations; secret values are synced separately.
      runtimeSecrets = [
        {
          item = "secret--context7--api-key";
          destinations.environmentVariable = "CONTEXT7_API_KEY";
        }
        {
          item = "secret--github--personal-access-token";
          destinations.environmentVariable = "GITHUB_PERSONAL_ACCESS_TOKEN";
        }
      ];
      stateDirectory = "${config.home.homeDirectory}/.local/state/bitwarden-secrets";
      declaredSecrets = map
        (secret:
          let
            destinations = secret.destinations or { file = { }; };
            environmentVariable = destinations.environmentVariable or null;
            fileDestination = destinations.file or null;
            filePath =
              if fileDestination == null then
                null
              else
                (fileDestination.path or "${stateDirectory}/${secret.item}");
            environmentPath =
              if environmentVariable == null then
                null
              else if filePath != null then
                filePath
              else
                "${stateDirectory}/${secret.item}";
            declaredDestinations =
              (lib.optionalAttrs (environmentVariable != null) {
                environment = {
                  name = environmentVariable;
                  path = environmentPath;
                };
              })
              // (lib.optionalAttrs (fileDestination != null) {
                file = {
                  path = filePath;
                }
                // lib.optionalAttrs ((fileDestination.argument or null) != null) {
                  argument = fileDestination.argument;
                };
              });
          in
          assert environmentVariable != null || fileDestination != null;
          {
            inherit (secret) item;
            destinations = declaredDestinations;
          }
        )
        runtimeSecrets;
    in
    {
      home.packages = [
        pkgs.bitwarden-desktop
        pkgs.bitwarden-cli
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.bitwarden-secret-tools
      ];

      # The generated manifest contains destinations and item names, never secret values.
      xdg.configFile."bw-secret/secrets.json".text = builtins.toJSON {
        schemaVersion = 1;
        inherit stateDirectory;
        secrets = declaredSecrets;
      };

      home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      };
    };
}
