{
  config.perSystem =
    { pkgs, ... }:
    {
      checks.statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
        statix check --config ${../checks/statix.toml} ${../.}
        touch "$out"
      '';
    };
}
