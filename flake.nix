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

    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

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

    # 3.16.17 hangs the agent Shell on this host: ExtHostShellExec still probes
    # cursorsandbox, which fails unshare(EPERM) inside the Nix FHS wrapper and
    # never falls back. 3.15.6 did. Pin until that path is fixed.
    code-cursor-nix.url = "github:jacopone/code-cursor-nix/4c42c3db6d67b3a71ee5429bff33e29555b8dd07";

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

    # Pinned to the last v4 (Quickshell-based) revision. Noctalia v5 is a fresh
    # rewrite with a TOML config format and is still alpha; keep it out of
    # `nix flake update` until we intentionally migrate.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell/272cd91408b5ff6e329e6397eed042fe422069e7";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inputs = inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.home-manager.flakeModules.home-manager
        inputs.nix-darwin.flakeModules.default
      ]
      ++ (inputs.import-tree ./modules).imports
      ++ (inputs.import-tree ./hosts).imports;
    };
}
