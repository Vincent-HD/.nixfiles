###
### This file defines global options that are shared across all modules (NixOS and Home Manager)
###
{ lib, ... }:
{
  config.systems = [ "x86_64-linux" ];

  options.flake.username = lib.mkOption {
    type = lib.types.str;
    description = "Primary username shared across all modules";
  };
}
