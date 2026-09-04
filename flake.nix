{
  description = "Vincent's NixOS, nix-darwin, and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nix-darwin master requires the matching nixpkgs-unstable branch. Keep this separate from
    # the NixOS host's nixos-unstable package set.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    flake-utils.url = "github:numtide/flake-utils";

    import-tree.url = "github:vic/import-tree";

    # Remote Agent Skills remain reproducible through flake.lock; agentSkills
    # links only the explicitly selected upstream skill directories.
    context7-skills = {
      url = "github:upstash/context7";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    humanlayer-skills = {
      url = "github:humanlayer/skills";
      flake = false;
    };

    # Selected Ponytail skills and lifecycle hook sources. Codex hooks and the
    # Cursor rule are wired below; the rest of the upstream repository is unused.
    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    code-cursor-nix.url = "github:jacopone/code-cursor-nix";

    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The platform module is used without importing nix-gaming's optional game packages.
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Keep this input on its release branch and do not follow its nixpkgs input: its README
    # requires the exact nixpkgs revision used for its prebuilt kernel cache.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jjui = {
      url = "github:idursun/jjui";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # DankMaterialShell stable branch; Home Manager provides the per-user shell,
    # settings, Niri integration, and reproducible plugin sources.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned screen capture toolbar: photo and GPU-backed video recording from
    # the DMS bar. Keep the plugin source in the flake lock instead of installing
    # it imperatively through the DMS registry.
    screen-capture-toolbar = {
      url = "github:JDKamalakar/DMS-ScreenCapture_Toolbar/2b923cc95faa36876d790df6fc1ed575388e966d";
      flake = false;
    };

    # Quick Capture provides the annotated screenshot workflow and a DankBar
    # widget. The pinned revision is kept declarative so activation does not
    # depend on a mutable plugin registry checkout.
    quick-capture = {
      url = "github:hthienloc/dms-quick-capture/8e923d1604fd860007f0d5a3a3088011f253f2c1";
      flake = false;
    };

    # First-party DMS plugins, including Dank Actions used for the EasyEffects
    # toggle that used to be a local Noctalia-style widget.
    dms-plugins = {
      url = "github:AvengeMedia/dms-plugins/3ad0e7845b62a9aca56f7959dd086b2a85655079";
      flake = false;
    };

    # Pinned to the last v4 (Quickshell-based) revision. Noctalia v5 is a fresh
    # rewrite with a TOML config format and is still alpha; keep it out of
    # `nix flake update` until we intentionally migrate.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell/272cd91408b5ff6e329e6397eed042fe422069e7";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local Tokitoki flake while developing the package and shell integrations.
    tokitoki.url = "path:/home/vincent/lab/tokitoki";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inputs = inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.home-manager.flakeModules.home-manager
        inputs.nix-darwin.flakeModules.default
        (inputs.import-tree ./modules)
        (inputs.import-tree ./hosts)
      ];
    };
}
