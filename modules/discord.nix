{ inputs, ... }:
{
  # Home Manager side: Discord via Nixcord / Equicord
  config.flake.modules.homeManager.discord =
    { pkgs, ... }:
    {
      imports = [ inputs.nixcord.homeModules.nixcord ];

      programs.nixcord = {
        enable = true;

        discord = {
          vencord.enable = false;
          equicord = {
            enable = true;

            # Use Nixcord's package output so its pinned pnpm/SQLite toolchain matches
            # the fixed-output dependency hash published with the Nixcord revision.
            package = inputs.nixcord.packages.${pkgs.system}.equicord;
          };
        };

        config.plugins = {
          biggerStreamPreview.enable = true;
          fakeNitro.enable = true;
          streamingCodecDisabler.enable = true;
          betterFolders.enable = true;
          voiceMessages.enable = true;
          volumeBooster.enable = true;
        };
      };
    };
}
