{ inputs, config, ... }:
let
  username = config.flake.username;
in
{
  # NixOS side: system-level dev tooling (add nix-ld, compilers, etc. here)
  config.flake.modules.nixos.coding =
    { ... }:
    {
      programs.nix-ld.enable = true;

      virtualisation.docker.enable = true;

      users.users.${username}.extraGroups = [ "docker" ];
    };

  # Home Manager side: editors and dev tools
  config.flake.modules.homeManager.coding =
    { pkgs, config, ... }:
    {
      home.packages = [
        pkgs.vscode
        inputs.code-cursor-nix.packages.${pkgs.system}.cursor
        pkgs.opencode
        pkgs.neovim
        pkgs.vim
        pkgs.uv
        pkgs.nixd
      ];

      programs.bash.enable = true;
      programs.bash.shellAliases = {
        nixos-switch = "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/.nixfiles#pc-fixe";
      };

      programs.git = {
        enable = true;
        settings = {
          user.name = "Vincent-HD";
          user.email = "vincenthoudan@gmail.com";
        };
      };
    };
}
