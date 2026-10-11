{
  # Manage Equibop and its Equicord plugin settings in Home Manager on both hosts.
  config.flake.modules.homeManager.equibop =
    { pkgs, ... }:
    {
      programs.equibop = {
        enable = true;
        package = if pkgs.stdenv.hostPlatform.isLinux then pkgs.equibop else null;

        equicord.settings.plugins = {
          BiggerStreamPreview.enabled = true;
          FakeNitro.enabled = true;
          StreamingCodecDisabler.enabled = true;
          BetterFolders.enabled = true;
          VoiceMessages.enabled = true;
          VolumeBooster.enabled = true;
        };
      };
    };

  # Install the native macOS app through the upstream-recommended Homebrew cask.
  config.flake.modules.darwin.equibop =
    { ... }:
    {
      homebrew.casks = [ "equibop" ];
    };
}
