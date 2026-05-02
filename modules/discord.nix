{ inputs, ... }:
{
  # Home Manager side: Discord with Vencord and NVIDIA VAAPI flags.
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
          vencord.enable = true;
          package = discordWithVaapi;
        };

        config.plugins.fakeNitro.enable = true;
        config.plugins.volumeBooster.enable = true;
      };
    };
}
