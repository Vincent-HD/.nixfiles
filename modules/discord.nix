{ inputs, ... }:
{
  # Home Manager side: Discord via Nixcord / Equicord
  config.flake.modules.homeManager.discord =
    { ... }:
    {
      imports = [ inputs.nixcord.homeModules.nixcord ];

      programs.nixcord = {
        enable = true;

        discord = {
          vencord.enable = false;
          equicord.enable = true;
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
