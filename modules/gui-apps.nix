{ ... }:
{
  # Home Manager: desktop applications that used to be installed by hand on the
  # Mac. nixpkgs provides all of them, so Home Manager owns the bundles instead
  # of Homebrew or a drag-and-drop install.
  config.flake.modules.homeManager.guiApps =
    { pkgs, lib, ... }:
    let
      # The upstream Scroll Reverser zip stores an AppleDouble sidecar next to one
      # of its resources (`Contents/Resources/._IntroShot.png`). nixpkgs installs
      # the unzip output unchanged, and that extra file is not in the Developer ID
      # signature's sealed resource list, so macOS reports "a sealed resource is
      # missing or invalid" and Gatekeeper offers to move the app to the Trash.
      # Dropping the file repairs the seal instead of breaking it, because it was
      # never part of the signature.
      scrollReverser = pkgs.scroll-reverser.overrideAttrs (previousAttrs: {
        postInstall = (previousAttrs.postInstall or "") + ''
          find "$out/Applications" -name '._*' -delete
        '';
      });
    in
    {
      home.packages = [
        pkgs.slack
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # ChatGPT for macOS ships arm64-only, and Scroll Reverser is macOS-only.
        pkgs.chatgpt
        scrollReverser
        # Google Chrome, unfree but allowed by the macOS host. The manually
        # installed copy is restored by Google's updater, so the migration also
        # disables that updater. Organization agents keep working because Chrome
        # reads their native messaging hosts from the bundle-independent
        # /Library/Google/Chrome/NativeMessagingHosts directory.
        pkgs.google-chrome
      ];
    };
}
