{ ... }:
let
  # Spreadsheet formats LibreOffice Calc opens by default; WordCraft keeps text documents.
  spreadsheetMimeTypes = [
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
    "application/vnd.ms-excel"
    "application/vnd.ms-excel.sheet.macroEnabled.12"
    "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
    "application/vnd.oasis.opendocument.spreadsheet"
    "text/csv"
    "text/tab-separated-values"
  ];
  spreadsheetUniformTypeIdentifiers = [
    "org.openxmlformats.spreadsheetml.sheet"
    "org.openxmlformats.spreadsheetml.sheet.macroenabled"
    "com.microsoft.excel.xls"
    "com.microsoft.excel.sheet.binary.macroenabled"
    "org.oasis-open.opendocument.spreadsheet"
    "public.comma-separated-values-text"
    "public.tab-separated-values-text"
  ];
in
{
  # Home Manager: LibreOffice for spreadsheets, including workbooks too large for GridCraft.
  config.flake.modules.homeManager.libreoffice =
    { pkgs, lib, ... }:
    lib.mkMerge [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        home.packages = [ pkgs.libreoffice ];
        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs spreadsheetMimeTypes (mimeType: [ "calc.desktop" ]);
        };
      })

      # macOS: the Homebrew cask (darwin.libreoffice) installs the app; point spreadsheets at it.
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.activation.libreofficeFileAssociations = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          ''
            if [ -d /Applications/LibreOffice.app ]; then
          ''
          + lib.concatMapStrings (uniformTypeIdentifier: ''
            run ${lib.getExe pkgs.duti} -s org.libreoffice.script ${uniformTypeIdentifier} all
          '') spreadsheetUniformTypeIdentifiers
          + ''
            fi
          ''
        );
      })
    ];

  # nix-darwin: nixpkgs builds LibreOffice for Linux only, so macOS uses the cask.
  config.flake.modules.darwin.libreoffice =
    { ... }:
    {
      homebrew.casks = [ "libreoffice" ];
    };
}
