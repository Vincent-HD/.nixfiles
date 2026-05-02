{ inputs, ... }:
{
  # Home Manager side: Discord with Equicord and NVIDIA VAAPI flags.
  config.flake.modules.homeManager.discord =
    { pkgs, ... }:
    let
      discordWithVaapi = (inputs.nixcord.packages.${pkgs.system}.discord).overrideAttrs (previousAttrs: {
        postFixup = (previousAttrs.postFixup or "") + ''
          substituteInPlace "$out/bin/Discord" \
            --replace \
              '--enable-features=WaylandWindowDecorations' \
              '--enable-features=WaylandWindowDecorations,AcceleratedVideoDecodeLinuxGL,VaapiOnNvidiaGPUs,AcceleratedVideoEncoder' \
            --replace \
              '--enable-wayland-ime=true}}' \
              '--enable-wayland-ime=true --use-gl=egl}}'
        '';
      });
    in
    {
      imports = [ inputs.nixcord.homeModules.nixcord ];

      programs.nixcord = {
        enable = true;

        discord = {
          enable = true;
          branch = "stable";
          vencord.enable = false;
          equicord.enable = true;
          package = discordWithVaapi;
        };

        config.plugins.neverPausePreviews.enable = true;
        config.plugins.betterFolders.enable = true;
        config.plugins.equibopStreamFixes.enable = true;
        config.plugins.streamingCodecDisabler.enable = true;
        config.plugins.voiceMessageTranscriber.enable = true;
        config.plugins.volumeBooster.enable = true;
      };
    };
}
