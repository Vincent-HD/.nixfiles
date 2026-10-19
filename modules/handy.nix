{ ... }:
{
  # Home Manager: offline speech transcription with Wayland text input on Linux.
  config.flake.modules.homeManager.handy =
    { pkgs, lib, ... }:
    {
      home.packages = [ pkgs.handy ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.wtype ];
    };
}
