{ ... }:
{
  # Home Manager: desktop applications that used to be installed by hand on the
  # Mac. nixpkgs provides all of them, so Home Manager owns the bundles instead
  # of Homebrew or a drag-and-drop install.
  config.flake.modules.homeManager.guiApps =
    { pkgs, lib, ... }:
    {
      home.packages = [
        pkgs.slack
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # ChatGPT for macOS ships arm64-only, and Scroll Reverser is macOS-only.
        pkgs.chatgpt
        pkgs.scroll-reverser
      ];
    };
}
