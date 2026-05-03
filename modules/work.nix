{ ... }:
{
  # Home Manager side: Work tools
  config.flake.modules.homeManager.work =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.doppler
        pkgs.awscli2
        pkgs.ssm-session-manager-plugin
        pkgs.jetbrains.datagrip
      ];

      programs.bash.initExtra = ''
        setup_worktree() {
          echo "Configuring backend"
          cd apps/backend && \
            doppler setup --project backend --config development --no-interactive && \
            pnpm gen:dotenv && \
            pnpm gen:i18n && \
            cd -

          echo "Configuring frontend"
          cd apps/frontend && doppler setup --project frontend --config development --no-interactive && \
            pnpm gen:dotenv && \
            cd -

          echo "Configuring admin-front"
          cd apps/admin-front && doppler setup --project frontend --config development --no-interactive && \
            pnpm gen:dotenv && \
            cd -

          echo "Configuring service-airtable-proxy"
          cd apps/service-airtable-proxy && doppler setup --project service-airtable-proxy --config development --no-interactive && \
            pnpm gen:dotenv && \
            cd -

          echo "Copy .vscode folder"
          cp -R ../../welii/.vscode ./

          echo "Installing dependencies"
          pnpm install --prefer-offline
        }
      '';
    };
}
