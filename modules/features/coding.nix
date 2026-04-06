{ inputs, config, ... }:
let
  username = config.flake.username;
in
{
  # NixOS side: system-level dev tooling (add nix-ld, compilers, etc. here)
  flake.modules.nixos.coding =
    { ... }:
    {
      programs.nix-ld.enable = true;

      virtualisation.docker.enable = true;

      users.users.${username}.extraGroups = [ "docker" ];
    };

  # Home Manager side: editors and dev tools
  flake.modules.homeManager.coding =
    { pkgs, config, ... }:
    {
      home.packages = with pkgs; [
        vscode
        inputs.code-cursor-nix.packages.${pkgs.system}.cursor
        opencode
        neovim
        vim
        uv
        nixd
        docker-compose
      ];

      programs.bash.enable = true;
      programs.bash.shellAliases = {
        nixos-switch =
          "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/.nixfiles#main";
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
