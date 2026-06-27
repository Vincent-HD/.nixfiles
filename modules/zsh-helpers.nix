{ ... }:
{
  config.flake.modules.homeManager.zshHelpers =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.zsh-autosuggestions
        pkgs.zsh-syntax-highlighting
      ];

      xdg.configFile."nixfiles/zsh-helpers.zsh".text = ''
        source "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
      '';
    };
}
