{ lib, ... }:
{
  config.systems = [ "x86_64-linux" ];

  options.flake.username = lib.mkOption {
    type = lib.types.str;
    default = "vincent";
    description = "Primary username shared across all modules";
  };

  config.flake.username = "vincent";
}
