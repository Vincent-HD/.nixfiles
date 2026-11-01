{ ... }:
{
  # BlueZ daemon for the Realtek RTL8761BU USB dongle (0bda:8771); DMS provides the UI.
  config.flake.modules.nixos.bluetooth =
    { ... }:
    {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      # USB autosuspend makes the RTL8761BU time out on HCI commands (scan) and reset in a loop.
      boot.extraModprobeConfig = ''
        options btusb enable_autosuspend=0
      '';
    };
}
