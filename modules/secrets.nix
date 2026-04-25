{ config, ... }:
let
  username = config.flake.username;
in
{
  # System secrets decrypted by sops-nix.
  config.flake.modules.nixos.secrets =
    { ... }:
    {
      sops.age.keyFile = "/home/${username}/.config/sops/age/keys.txt";
      sops.defaultSopsFile = ../secrets/github-token.yaml;
      sops.secrets.github_token = {
        owner = username;
        path = "/home/${username}/.config/opencode/github-token";
      };
    };
}
