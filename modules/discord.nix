{ ... }:
{
  # Home Manager side: Discord via Nixcord (Vencord)
  # The nixcord shared module is loaded in the composition root (hosts/main/default.nix)
  config.flake.modules.homeManager.discord =
    { ... }:
    {
      programs.nixcord = {
        enable = true;
        discord.vencord.enable = true;
        config.plugins.fakeNitro.enable = true;
      };
    };
}
