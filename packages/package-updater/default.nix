{
  lib,
  writeShellApplication,
  bun,
  curl,
  gitMinimal,
  gnugrep,
  gnused,
  jq,
  nix-update,
  nodejs_24,
}:
let
  # Authenticated GitHub REST helper for `latestVersion` commands; uses GITHUB_TOKEN when set.
  githubApi = writeShellApplication {
    name = "github-api";
    runtimeInputs = [ curl ];
    text = ''
      authorization=()
      if [ -n "''${GITHUB_TOKEN:-}" ]; then
        authorization=(--header "Authorization: Bearer $GITHUB_TOKEN")
      fi
      exec curl --fail --silent --show-error --location \
        --header "Accept: application/vnd.github+json" "''${authorization[@]}" \
        "https://api.github.com/$1"
    '';
  };

  packageUpdater = writeShellApplication {
    name = "package-updater";
    runtimeInputs = [
      bun
      curl
      gitMinimal
      githubApi
      gnugrep
      gnused
      jq
      nix-update
      nodejs_24
    ];
    text = ''
      exec bun ${./update-package.ts} "$@"
    '';
    passthru = {
      # Build a package's `passthru.updateScript`: nix-update bumps the version and the
      # running system's `src`, then every other `passthru.sources` fetch is re-hashed.
      #   attr          flake package attribute
      #   file          the Nix file holding the version and hashes (usually ./default.nix)
      #   nixUpdateArgs extra nix-update flags, e.g. [ "--use-github-releases" ]
      #   latestVersion shell command printing the target version when nix-update cannot find it
      #   postUpdate    Bun script for coupled artifacts, run only after a version change
      script =
        {
          attr,
          file,
          nixUpdateArgs ? [ ],
          latestVersion ? null,
          postUpdate ? null,
        }:
        [
          (lib.getExe packageUpdater)
          "--attr=${attr}"
          "--file=${toString file}"
        ]
        ++ map (argument: "--nix-update-arg=${argument}") nixUpdateArgs
        ++ lib.optional (latestVersion != null) "--latest-version=${latestVersion}"
        ++ lib.optional (postUpdate != null) "--post-update=${postUpdate}";
    };
    meta.description = "Update a pinned flake package with nix-update and refresh its other platform hashes";
  };
in
packageUpdater
