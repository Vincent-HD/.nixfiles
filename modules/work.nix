{ ... }:
{
  # Home Manager side: Work tools
  config.flake.modules.homeManager.work =
    { pkgs, ... }:
    let
      setupWorktree = pkgs.writeShellApplication {
        name = "setup_worktree";
        runtimeInputs = [ pkgs.doppler ];
        text = ''
          echo "Configuring backend"
          (
            cd apps/backend
            doppler setup --project backend --config development --no-interactive
            pnpm gen:dotenv
            pnpm gen:i18n
          )

          echo "Configuring frontend"
          (
            cd apps/frontend
            doppler setup --project frontend --config development --no-interactive
            pnpm gen:dotenv
          )

          echo "Configuring admin-front"
          (
            cd apps/admin-front
            doppler setup --project frontend --config development --no-interactive
            pnpm gen:dotenv
          )

          echo "Configuring service-airtable-proxy"
          (
            cd apps/service-airtable-proxy
            doppler setup --project service-airtable-proxy --config development --no-interactive
            pnpm gen:dotenv
          )

          echo "Copy .vscode folder"
          cp -R ../../welii/.vscode ./

          echo "Installing dependencies"
          pnpm install --prefer-offline
        '';
      };
    in
    {
      home.packages = [
        pkgs.doppler
        pkgs.awscli2
        pkgs.ssm-session-manager-plugin
        pkgs.jetbrains.datagrip
        setupWorktree
      ];
    };
}
