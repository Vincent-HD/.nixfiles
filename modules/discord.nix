{ ... }:
{
  # Home Manager side: Vesktop with Vencord
  config.flake.modules.homeManager.discord =
    { pkgs, ... }:
    let
      # Match the Chromium flag reported in the forum post.
      vesktopVideoArgs = "--enable-global-vaapi-lock";

      vesktopWithVaapi = pkgs.vesktop.overrideAttrs (previousAttrs: {
        postFixup = previousAttrs.postFixup + ''
          wrapProgram $out/bin/vesktop \
            --add-flags ${pkgs.lib.escapeShellArg vesktopVideoArgs}
        '';
      });
    in
    {
      programs.vesktop = {
        enable = true;
        package = vesktopWithVaapi;
        settings = {
          hardwareAcceleration = true;
          hardwareVideoAcceleration = true;
        };

        vencord.settings.plugins.FakeNitro = {
          enabled = true;
        };
      };
    };
}
