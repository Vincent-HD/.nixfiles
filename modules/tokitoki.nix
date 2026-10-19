{ inputs, ... }:
{
  # Home Manager: install Tokitoki on every host supported by its upstream package.
  config.flake.modules.homeManager.tokitoki =
    { lib, pkgs, ... }:
    {
      imports = [ inputs.tokitoki.homeManagerModules.default ];
      programs.tokitoki.enable = true;
      # The macOS menubar polls on its own; on Linux nothing else refreshes live
      # provider quotas (Claude session/weekly) between harness log scans.
      programs.tokitoki.poll.enable = lib.mkIf pkgs.stdenv.hostPlatform.isLinux true;
    };
}
