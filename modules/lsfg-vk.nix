{ inputs, ... }:
{
  config.flake.modules.nixos.lsfgVk =
    { pkgs, ... }:
    let
      lsfgVk = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.lsfg-vk;
    in
    {
      # Install both Vulkan layer architectures, the CLI/UI, and validation tools in the host profile.
      environment.systemPackages = [
        lsfgVk
        pkgs.vulkan-tools
      ];

      # Place both layer architectures inside Steam's FHS environment for Proton-launched Vulkan apps.
      programs.steam.extraPackages = [
        lsfgVk
        pkgs.vulkan-tools
      ];
    };
}
