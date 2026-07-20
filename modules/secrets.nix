{ config, ... }:
let
  username = config.flake.username;
  mkSopsConfig =
    {
      homeDirectory,
    }:
    _: {
      sops = {
        age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";
        defaultSopsFile = ../secrets/github-token.yaml;

        secrets = {
          github_token = {
            owner = username;
            mode = "0400";
            path = "${homeDirectory}/.config/agent-mcp/github-token";
          };

          context7_token = {
            owner = username;
            mode = "0400";
            path = "${homeDirectory}/.config/agent-mcp/context7-token";
          };
        };
      };
    };
in
{
  # System secrets decrypted by sops-nix.
  config.flake.modules.nixos.secrets = mkSopsConfig {
    homeDirectory = "/home/${username}";
  };

  # Both hosts receive the shared API tokens from the encrypted secret file.
  config.flake.modules.darwin.secrets = mkSopsConfig {
    homeDirectory = "/Users/${username}";
  };
}
