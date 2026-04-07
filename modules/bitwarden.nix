{ config, ... }:
let
  username = config.flake.username;
in
{
  # Home Manager side: Bitwarden password manager + SSH agent
  config.flake.modules.homeManager.bitwarden =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.bitwarden-desktop
      ];

      home.sessionVariables = {
        SSH_AUTH_SOCK = "/home/${username}/.bitwarden-ssh-agent.sock";
      };
    };
}
