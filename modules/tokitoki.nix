{ inputs, ... }:
{
  # Home Manager: install Tokitoki on every host supported by its upstream package.
  config.flake.modules.homeManager.tokitoki = {
    imports = [ inputs.tokitoki.homeManagerModules.default ];
    programs.tokitoki.enable = true;
  };
}
