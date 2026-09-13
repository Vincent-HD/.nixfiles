{ ... }:
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
    {
      home.packages = [
        pkgs.bitwarden-desktop
      ];

      home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      };
    };
}
