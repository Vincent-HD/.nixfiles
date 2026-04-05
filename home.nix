{ config, pkgs, inputs, ... }:

{
  home.username = "vincent";
  home.homeDirectory = "/home/vincent";

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    kdePackages.kate
    opencode
    vscode
    inputs.code-cursor-nix.packages.${pkgs.system}.cursor
    neovim
    git
    vim
    brave
    bitwarden-desktop
    spotify
  ];

  programs.home-manager.enable = true;

  programs.nixcord = {
    enable = true;
    discord.vencord.enable = true;
    config.plugins.fakeNitro.enable = true;
  };
}
