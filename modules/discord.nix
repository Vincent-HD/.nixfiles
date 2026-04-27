{ ... }:
{
  # Home Manager side: Vesktop with Vencord
  config.flake.modules.homeManager.discord =
    { pkgs, ... }:
    let
      # Electron 41.x is the Chromium 146 line.
      vesktopVideoArgs = "--enable-global-vaapi-lock";

      vesktopWithVaapi =
        (pkgs.vesktop.override {
          electron_40 = pkgs.electron_41;
        }).overrideAttrs
          (previousAttrs: {
            # Upstream 1.6.5 still checks for Electron 40 in package.json.
            # Keep the 41.x runtime, but bypass the guard and use the matching dist tree.
            preBuild =
              pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                cp -r ${pkgs.electron_41.dist} Electron.app .
                chmod -R u+w Electron.app
              ''
              + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                cp -r ${pkgs.electron_41.dist} electron-dist
                chmod -R u+w electron-dist
              '';

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
