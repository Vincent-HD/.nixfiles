{ inputs, ... }:
{
  # Home Manager: tuyau, the PipeWire patchbay (graph editor and CLI).
  config.flake.modules.homeManager.tuyau =
    { pkgs, ... }:
    {
      imports = [ inputs.tuyau.homeManagerModules.default ];

      programs.tuyau = {
        enable = true;

        # Use the pinned release binary instead of the input's from-source Rust build.
        package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.tuyau;

        # Run `tuyau watch` as a user service: it recreates the links and virtual devices
        # saved from the editor (and any declared in `settings`) whenever their nodes appear.
        service.enable = true;
      };
    };
}
