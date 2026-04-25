{ inputs, ... }:
{
  config.flake.modules.homeManager.noctalia-plugins-dependencies =
    { config, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      home.packages = with pkgs; [
        # screen-toolkit dependencies
        curl
        ffmpeg
        gifski
        grim
        imagemagick
        jq
        slurp
        tesseract
        translate-shell
        wl-clipboard
        wl-screenrec
        zbar
        # end of screen-toolkit dependencies
      ];

      # NOTE: We do NOT use `programs.noctalia-shell.plugins` here because
      # the Noctalia Home Manager module manages plugins.json as a read-only
      # symlink into the Nix store. Noctalia needs to write to plugins.json
      # to track plugin state, migrations, and updates.
      #
      # Instead, install the plugin manually into ~/.config/noctalia/plugins/
      # and let Noctalia create and manage plugins.json itself.
      # The screen-toolkit plugin can be downloaded from:
      # https://github.com/noctalia-dev/noctalia-plugins/tree/main/screen-toolkit
    };
}
