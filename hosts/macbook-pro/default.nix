{ inputs, config, ... }:
let
  darwin = config.flake.modules.darwin;
  hm = config.flake.modules.homeManager;
  username = config.flake.username;
in
{
  config.flake.darwinConfigurations."macbook-pro" = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      darwin.macbookProConfiguration
      darwin.deskflow
      darwin.rustdesk

      inputs.home-manager-darwin.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.users.${username} = {
          imports = [
            # Migrate one application at a time. Keep this list deliberately small.
            hm.browser
            hm.btop
            hm.coding
            hm.discord
            hm.mcfly
            hm.starship
            hm.sunshine
            hm.work
            hm.zoxide
          ];

          home.username = username;
          home.homeDirectory = "/Users/${username}";
          home.stateVersion = "25.11";
        };
      }
    ];
  };
}
