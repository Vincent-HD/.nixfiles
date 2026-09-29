{ inputs, ... }:
{
  # Let the Linux client receive multicast discovery beacons from the phone.
  config.flake.modules.nixos.wifiAudioStreaming =
    { ... }:
    {
      networking.firewall.allowedUDPPorts = [ 9091 ];
    };

  # Install the desktop receiver on Linux and macOS.
  config.flake.modules.homeManager.wifiAudioStreaming =
    { pkgs, lib, ... }:
    let
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wifi-audio-streaming;
    in
    {
      home.packages = [ package ];

      xdg.desktopEntries.wifi-audio-streaming = lib.mkIf isLinux {
        name = "WiFi Audio Streaming";
        genericName = "Network audio receiver";
        comment = "Send or receive audio over the local network";
        exec = lib.getExe package;
        icon = "audio-x-generic";
        terminal = false;
        categories = [
          "AudioVideo"
          "Network"
        ];
      };
    };
}
