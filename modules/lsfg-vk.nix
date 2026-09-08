{ ... }:
{
  config.flake.modules.nixos.lsfgVk =
    { pkgs, ... }:
    let
      lsfgVk = pkgs.callPackage ../packages/lsfg-vk { };
      lsfgVk32 = pkgs.pkgsi686Linux.callPackage ../packages/lsfg-vk {
        buildCli = false;
        buildUi = false;
        multilib = true;
      };
    in
    {
      # Install both Vulkan layer architectures, the CLI/UI, and validation tools in the host profile.
      environment.systemPackages = [
        lsfgVk
        lsfgVk32
        pkgs.vulkan-tools
      ];

      # Place both layer architectures inside Steam's FHS environment for Proton-launched Vulkan apps.
      programs.steam.extraPackages = [
        lsfgVk
        lsfgVk32
        pkgs.vulkan-tools
      ];
    };
}
