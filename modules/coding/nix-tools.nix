{ ... }:
{
  config.flake.modules.homeManager.codingNixTools =
    { pkgs, lib, ... }:
    {
      home.packages = [
        pkgs.nil
        pkgs.nixfmt
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        pkgs.mcp-nixos
      ];
    };
}
