{ ... }:
{
  # NixOS system-wide: install the deskflow binary on PATH for every user.
  # `pkgs.deskflow` from nixpkgs is the upstream-recommended install path on Linux.
  # On Wayland, Deskflow uses libei via the XDG Desktop Portal `InputCapture`
  # interface. `modules/niri.nix` overrides the portal dispatcher's
  # XDG_CURRENT_DESKTOP to `gnome` so the gnome impl (UseIn=gnome) activates
  # for the niri session; without that, Deskflow exits with
  # `CreateSession failed` for InputCapture.
  config.flake.modules.nixos.deskflow =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.deskflow
      ];
    };

  # Home Manager: install the deskflow binary for the logged-in user.
  # The package ships its own GUI (`deskflow`) and CLI; no service is enabled here.
  config.flake.modules.homeManager.deskflow =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.deskflow
      ];
    };

  # nix-darwin: install Deskflow via the upstream `deskflow/tap` Homebrew cask.
  # nixpkgs `deskflow` is Linux-only; on macOS, the project distributes an unsigned
  # app that requires Homebrew's quarantine handling, so Homebrew owns the install.
  # See `docs/MACOS_MIGRATION.md` for the full rationale.
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
