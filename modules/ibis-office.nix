{ inputs, ... }:
{
  # Home Manager: ibisOffice, a GPU-rendered office suite on trial for huge spreadsheets.
  # LibreOffice keeps the default file associations; open files here with "Open with".
  config.flake.modules.homeManager.ibisOffice =
    { pkgs, ... }:
    {
      home.packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ibis-office ];
    };
}
