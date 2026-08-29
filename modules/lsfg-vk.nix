{ ... }:
{
  config.flake.modules.nixos.lsfgVk =
    { pkgs, ... }:
    let
      lsfgVk = pkgs.callPackage ../packages/lsfg-vk { };
    in
    {
      # Install the layer, CLI, UI, and Vulkan validation tools in the host profile.
      environment.systemPackages = [
        lsfgVk
        pkgs.vulkan-tools
      ];

      # Place the layer package inside Steam's FHS environment for Proton-launched Vulkan apps.
      programs.steam.extraPackages = [
        lsfgVk
        pkgs.vulkan-tools
      ];
    };
}
