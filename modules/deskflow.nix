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

      # Deskflow server listens for clients on TCP 24800 by default.
      networking.firewall.allowedTCPPorts = [ 24800 ];
    };

  # Home Manager: install the deskflow binary for the logged-in user.
  # The package ships its own GUI (`deskflow`) and CLI; no service is enabled here.
  config.flake.modules.homeManager.deskflow =
    { pkgs, lib, ... }:
    let
      deskflowX11 = pkgs.writeShellApplication {
        name = "deskflow-x11";
        runtimeInputs = [ pkgs.deskflow ];
        text = ''
          export XDG_SESSION_TYPE=x11
          export DISPLAY="''${DISPLAY:-:0}"
          export QT_QPA_PLATFORM=xcb
          exec deskflow "$@"
        '';
      };
    in
    {
      home.packages = [
        pkgs.deskflow
        deskflowX11
      ];

      # Niri does not implement the InputCapture portal yet, so force Deskflow
      # through Xwayland as a practical server-mode workaround.
      xdg.desktopEntries.deskflow-x11 = {
        name = "Deskflow (X11 workaround)";
        genericName = "Mouse and keyboard sharing utility";
        comment = "Launch Deskflow through Xwayland for compositors without InputCapture";
        exec = "${lib.getExe deskflowX11}";
        icon = "org.deskflow.deskflow";
        terminal = false;
        categories = [ "Utility" ];
        settings = {
          StartupWMClass = "deskflow";
        };
      };
    };

  # nix-darwin: install Deskflow via the upstream `deskflow/tap` Homebrew cask.
  # nixpkgs `deskflow` is Linux-only; on macOS, the project distributes an unsigned
  # app that requires Homebrew's quarantine handling, so Homebrew owns the install.
  # See `docs/MACOS_NIX_RESEARCH.md` for the macOS ownership rationale.
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
