{ ... }:
{
  # Keep the audio presets and device routing reproducible on the desktop host.
  config.flake.modules.homeManager.easyeffects =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Native presets omit the device selection for the external sidechain.
      sidechainSettings = pkgs.writeShellScript "easyeffects-sidechain" ''
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/easyeffects/db/compressorrc"} \
          --group soe --group 'Compressor#0' \
          --key sidechainInputDevice communication_sink.capture
      '';
    in
    {
      services.easyeffects = {
        enable = true;
        preset = {
          input = "Basic microphone chain";
          output = "Music Ducking";
        };

        # Keep native exports intact so each effect's parameters survive migration.
        extraPresets = {
          "Basic microphone chain" = builtins.fromJSON (
            builtins.readFile ./assets/basic-microphone-chain.json
          );
          "Music Ducking" = builtins.fromJSON (builtins.readFile ./assets/music-ducking.json);
          "Without Music Ducking" = builtins.fromJSON (builtins.readFile ./assets/without-music-ducking.json);
        };

        # Merge preferences into writable KConfig; leave transient UI state local.
        settings = {
          StreamInputs.inputDevice = "alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.mono-fallback";
          StreamOutputs.outputDevice = "alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo";
          Window.autostartOnLogin = false;
        };
      };

      # Append to HM's scalar ExecStartPre through a systemd drop-in, merging
      # just the routing key without freezing the writable effect database.
      xdg.configFile."systemd/user/easyeffects.service.d/sidechain.conf".text = ''
        [Service]
        ExecStartPre=${sidechainSettings}
      '';

      # Mask the app-created XDG autostart entry; the HM service owns startup.
      xdg.configFile."autostart/com.github.wwmm.easyeffects.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=EasyEffects
        Hidden=true
      '';
    };
}
