{ inputs, ... }:
let
  # Office formats ibisOffice opens by default: the types its Linux desktop entry declares,
  # plus legacy Word/PowerPoint and OpenDocument text/presentation, which its macOS bundle claims.
  officeMimeTypes = [
    # Spreadsheets
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
    "application/vnd.ms-excel"
    "application/vnd.ms-excel.sheet.macroEnabled.12"
    "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
    "application/vnd.ms-excel.template.macroEnabled.12"
    "application/vnd.oasis.opendocument.spreadsheet"
    "application/vnd.oasis.opendocument.spreadsheet-template"
    "text/csv"
    "text/tab-separated-values"
    # Documents
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
    "application/vnd.ms-word.document.macroEnabled.12"
    "application/vnd.ms-word.template.macroEnabled.12"
    "application/msword"
    "application/vnd.oasis.opendocument.text"
    # Presentations
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
    "application/vnd.openxmlformats-officedocument.presentationml.template"
    "application/vnd.ms-powerpoint.presentation.macroEnabled.12"
    "application/vnd.ms-powerpoint.slideshow.macroEnabled.12"
    "application/vnd.ms-powerpoint.template.macroEnabled.12"
    "application/vnd.ms-powerpoint"
    "application/vnd.oasis.opendocument.presentation"
    "application/vnd.oasis.opendocument.presentation-template"
  ];

  # macOS handlers: content types from the bundle's Info.plist, plus the macro-enabled
  # formats it only declares by extension (duti accepts ".ext" for those).
  officeUniformTypeIdentifiers = [
    "org.openxmlformats.spreadsheetml.sheet"
    "com.microsoft.excel.xls"
    "org.oasis-open.opendocument.spreadsheet"
    "public.comma-separated-values-text"
    "public.tab-separated-values-text"
    "org.openxmlformats.wordprocessingml.document"
    "com.microsoft.word.doc"
    "org.oasis-open.opendocument.text"
    "org.openxmlformats.presentationml.presentation"
    "com.microsoft.powerpoint.ppt"
    "org.oasis-open.opendocument.presentation"
    ".xlsm"
    ".docm"
    ".pptm"
  ];
in
{
  # Home Manager: ibisOffice, a GPU-rendered office suite that handles huge spreadsheets,
  # set as the default app for spreadsheets, documents and presentations on both hosts.
  config.flake.modules.homeManager.ibisOffice =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      ibisOffice = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ibis-office;
      lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
      appBundle = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/ibisOffice.app";
    in
    lib.mkMerge [
      { home.packages = [ ibisOffice ]; }

      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs officeMimeTypes (mimeType: [
            ibisOffice.passthru.desktopFile
          ]);
        };
      })

      # macOS: register the copied bundle, then point office types at it.
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.activation.ibisOfficeFileAssociations = lib.hm.dag.entryAfter [ "copyApps" ] (
          ''
            run ${lsregister} -f "${appBundle}"
          ''
          + lib.concatMapStrings (uniformTypeIdentifier: ''
            run ${lib.getExe pkgs.duti} -s ${ibisOffice.passthru.bundleIdentifier} ${uniformTypeIdentifier} all
          '') officeUniformTypeIdentifiers
        );
      })
    ];
}
