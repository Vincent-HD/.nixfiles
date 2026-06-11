{ config, ... }:
let
  username = config.flake.username;
in
{
  config.flake.modules.darwin.macbookProConfiguration =
    { pkgs, ... }:
    {
      system.primaryUser = username;

      users.users.${username} = {
        home = "/Users/${username}";
      };

      nixpkgs.config.allowUnfree = true;

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # The official multi-user Nix installer prepended its daemon snippet to
      # these stock macOS files. Authorize exactly those current files so the
      # first nix-darwin activation can adopt their ownership.
      environment.etc."bashrc".knownSha256Hashes = [
        "8b5e3466922d1ae34bc145e21c7e53e7329a7a7b58b148b436bd954d5e651ac3"
      ];
      environment.etc."zshrc".knownSha256Hashes = [
        "af60f7af4a5b4c1b0efe950e3e3f3ee8b136834ecb46fd7dba76f4b66adbc3e1"
      ];

      # Keep the implementation installed by the official Nix installer during the
      # first activation. Changing to Lix is a separate migration step.
      nix.package = pkgs.nix;

      system.stateVersion = 6;
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
