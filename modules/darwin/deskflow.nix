{ ... }:
{
  config.flake.modules.darwin.deskflow =
    { config, lib, ... }:
    let
      brew = "${config.homebrew.prefix}/bin/brew";
      homebrewUser = lib.escapeShellArg config.homebrew.user;
    in
    {
      homebrew = {
        enable = true;
        taps = [ "deskflow/tap" ];
        casks = [ "deskflow/tap/deskflow" ];

        onActivation = {
          cleanup = "none";
          autoUpdate = false;
          upgrade = false;
          extraEnv.HOMEBREW_NO_ANALYTICS = "1";
        };
      };

      # Homebrew requires explicit trust before it will load third-party casks.
      system.activationScripts.preActivation.text = ''
        if [ -x ${lib.escapeShellArg brew} ]; then
          sudo --user=${homebrewUser} --set-home ${lib.escapeShellArg brew} tap deskflow/tap
          sudo --user=${homebrewUser} --set-home ${lib.escapeShellArg brew} trust --tap deskflow/tap
        fi
      '';
    };
}
