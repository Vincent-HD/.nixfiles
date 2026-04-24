{ ... }:
{
  # Home Manager side: Vesktop with Vencord
  config.flake.modules.homeManager.discord =
    { pkgs, ... }:
    {
      programs.vesktop = {
        enable = true;
        package = pkgs.vesktop.overrideAttrs (previousAttrs: {
          postFixup = previousAttrs.postFixup + ''
            wrapProgram $out/bin/vesktop \
              --add-flags "--enable-features=AcceleratedVideoEncoder"
          '';
        });

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
