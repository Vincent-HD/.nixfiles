{ inputs, ... }:
{
  # Install Handy's prebuilt release and Wayland text input support.
  config.flake.modules.homeManager.handy =
    { pkgs, lib, ... }:
    {
      home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.handy
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.wtype ];
    };
}
