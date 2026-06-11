###
### This file defines global options that are shared across all modules (NixOS and Home Manager)
###
{ lib, ... }:
{
  config.systems = [
    "aarch64-darwin"
    "x86_64-linux"
  ];

  config.flake.username = "vincent";

  options.flake.username = lib.mkOption {
    type = lib.types.str;
    description = "Primary username shared across all modules";
  };
}
