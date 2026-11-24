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

  # LibreOffice UI backends to compare on huge sheets. GTK3 (the auto-detected default under
  # niri) and Qt6 on Wayland draw through Cairo; Skia GPU drawing only works on X11 (Xwayland).
  renderProfiles = {
    qt6-wayland = {
      SAL_USE_VCLPLUGIN = "qt6";
      QT_QPA_PLATFORM = "wayland";
    };
    qt6-x11-skia-vulkan = {
      SAL_USE_VCLPLUGIN = "qt6";
      QT_QPA_PLATFORM = "xcb";
      SAL_ENABLESKIA = "1";
      SAL_FORCESKIA = "1";
      SAL_SKIA = "vulkan";
    };
    qt6-x11-skia-raster = {
      SAL_USE_VCLPLUGIN = "qt6";
      QT_QPA_PLATFORM = "xcb";
      SAL_ENABLESKIA = "1";
      SAL_SKIA = "raster";
    };
    gtk3 = {
      SAL_USE_VCLPLUGIN = "gtk3";
    };
  };
in
{
  # Home Manager: LibreOffice for spreadsheets, including workbooks too large for GridCraft.
  config.flake.modules.homeManager.libreoffice =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # The Qt6 build ships the qt6, kf6, gtk3 and gen backends plus Skia.
      libreofficePackage = pkgs.libreoffice-qt6;
      launcherNames = [
        "libreoffice"
        "soffice"
        "scalc"
        "swriter"
        "simpress"
        "sdraw"
        "smath"
        "sbase"
      ];
      profileFlags =
        profile:
        lib.concatStringsSep " " (
          lib.mapAttrsToList (name: value: "--set-default ${name} ${value}") renderProfiles.${profile}
        );

      # Desktop entries run `libreoffice` from PATH, so wrapping the launchers applies the
      # chosen profile everywhere while explicit environment variables still win.
      libreofficeTuned = pkgs.symlinkJoin {
        name = "libreoffice-${config.custom.libreoffice.renderProfile}";
        paths = [ libreofficePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = lib.concatMapStrings (launcherName: ''
          rm "$out/bin/${launcherName}"
          makeWrapper ${libreofficePackage}/bin/${launcherName} "$out/bin/${launcherName}" \
            ${profileFlags config.custom.libreoffice.renderProfile}
        '') launcherNames;
        meta.mainProgram = "libreoffice";
      };

      # `libreoffice-render-test <profile> [file...]` opens Calc with one profile to compare scrolling.
      libreofficeRenderTest = pkgs.writeShellApplication {
        name = "libreoffice-render-test";
        text = ''
          profile="''${1:-}"
          case "$profile" in
          ${lib.concatStrings (
            lib.mapAttrsToList (name: variables: ''
              ${name})
                shift
                exec env ${
                  lib.concatStringsSep " " (lib.mapAttrsToList (key: value: "${key}=${value}") variables)
                } ${libreofficePackage}/bin/libreoffice --calc "$@"
                ;;
            '') renderProfiles
          )}
          *)
            echo "usage: libreoffice-render-test <${lib.concatStringsSep "|" (builtins.attrNames renderProfiles)}> [file...]" >&2
            echo "Close every LibreOffice window first: a running instance keeps its own backend." >&2
            exit 2
            ;;
          esac
        '';
      };
    in
    {
      # Pick the backend that scrolls best after comparing with libreoffice-render-test.
      options.custom.libreoffice.renderProfile = lib.mkOption {
        type = lib.types.enum (builtins.attrNames renderProfiles);
        default = "qt6-wayland";
        description = "LibreOffice UI backend and drawing settings used by the default launchers.";
      };

      config = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          home.packages = [
            libreofficeTuned
            libreofficeRenderTest
          ];
          xdg.mimeApps = {
            enable = true;
            defaultApplications = lib.genAttrs spreadsheetMimeTypes (_mimeType: [ "calc.desktop" ]);
          };

          # Calc's AutoInput scans the column on every keystroke, which lags on huge sheets.
          # LibreOffice rewrites this file on exit, so only edit it while no instance runs.
          home.activation.libreofficeCalcSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            registry="${config.xdg.configHome}/libreoffice/4/user/registrymodifications.xcu"
            if [ -f "$registry" ] && ! ${pkgs.procps}/bin/pgrep -x soffice.bin >/dev/null; then
              run ${lib.getExe pkgs.gnused} -i \
                -e '\|<item oor:path="/org.openoffice.Office.Calc/Input"><prop oor:name="AutoInput"|d' \
                -e 's|</oor:items>|<item oor:path="/org.openoffice.Office.Calc/Input"><prop oor:name="AutoInput" oor:op="fuse"><value>false</value></prop></item>\n</oor:items>|' \
                "$registry"
            fi
          '';
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
    };

  # nix-darwin: nixpkgs builds LibreOffice for Linux only, so macOS uses the cask.
  config.flake.modules.darwin.libreoffice =
    { ... }:
    {
      homebrew.casks = [ "libreoffice" ];
    };
}
