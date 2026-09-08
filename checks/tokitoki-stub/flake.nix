{
  description = "CI stub for the private local Tokitoki flake input";

  outputs = _inputs: {
    homeManagerModules.default =
      { lib, ... }:
      {
        options.programs.tokitoki.enable = lib.mkEnableOption "tokitoki";
      };
  };
}
