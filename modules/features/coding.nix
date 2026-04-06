{ inputs, ... }:
{
  # NixOS side: system-level dev tooling (add nix-ld, compilers, etc. here)
  flake.modules.nixos.coding =
    { ... }:
    {
      programs.nix-ld.enable = true;
    };

  # Home Manager side: editors and dev tools
  flake.modules.homeManager.coding =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        vscode
        inputs.code-cursor-nix.packages.${pkgs.system}.cursor
        opencode
        neovim
        vim
        uv
      ];

      programs.bash.enable = true;

      programs.git = {
        enable = true;
        userName = "Vincent-HD";
        userEmail = "vincenthoudan@gmail.com";
      };
    };
}
