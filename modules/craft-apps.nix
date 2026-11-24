{ inputs, ... }:
{
  # Home Manager: ArtCraft desktop apps (github.com/storytold) with per-app toggles
  # and default file associations on Linux (XDG mimeapps) and macOS (LaunchServices).
  config.flake.modules.homeManager.craftApps =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.custom.craftApps;
      craftPackages = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};

      # Default handlers per app. Only formats each app is the natural editor for are
      # claimed; common viewing formats the apps also accept (PNG/JPEG, HTML,
      # Markdown, SVG) stay with the existing viewers unless added per host.
      defaultAssociations = {
        pdfcraft = {
          mimeTypes = [ "application/pdf" ];
          uniformTypeIdentifiers = [ "com.adobe.pdf" ];
        };
        photocraft = {
          mimeTypes = [
            "application/x-photocraft"
            "image/x-paintnet"
            "image/openraster"
            "application/x-krita"
            "image/vnd.adobe.photoshop"
            "image/x-psd"
            "image/x-psb"
          ];
          uniformTypeIdentifiers = [
            "ai.storyteller.photocraft.document"
            "com.adobe.photoshop-image"
            "com.adobe.photoshop-large-image"
            "ai.storyteller.photocraft.pdn"
            "ai.storyteller.photocraft.ora"
            "ai.storyteller.photocraft.kra"
          ];
        };
        wordcraft = {
          mimeTypes = [
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "application/vnd.ms-word.document.macroEnabled.12"
            "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
            "application/vnd.ms-word.template.macroEnabled.12"
            "application/msword"
            "application/msword-template"
            "application/vnd.oasis.opendocument.text"
            "application/rtf"
            "text/rtf"
          ];
          uniformTypeIdentifiers = [
            "org.openxmlformats.wordprocessingml.document"
            "org.openxmlformats.wordprocessingml.template"
            "com.microsoft.word.doc"
            "org.oasis-open.opendocument.text"
            "public.rtf"
          ];
        };
      };

      appNames = builtins.attrNames defaultAssociations;
      enabledApps = lib.filterAttrs (_appName: appCfg: appCfg.enable) cfg;
      associatedApps = lib.filterAttrs (_appName: appCfg: appCfg.setDefaultApplication) enabledApps;

      # LaunchServices only resolves bundle IDs for apps it has registered.
      lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
      appsDirectory = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}";
      darwinAssociationCommands = lib.concatStrings (
        lib.mapAttrsToList (
          appName: appCfg:
          let
            craftPackage = craftPackages.${appName};
          in
          ''
            run ${lsregister} -f "${appsDirectory}/${craftPackage.passthru.displayName}.app"
          ''
          + lib.concatMapStrings (uniformTypeIdentifier: ''
            run ${lib.getExe pkgs.duti} -s ${craftPackage.passthru.bundleIdentifier} ${uniformTypeIdentifier} all
          '') appCfg.uniformTypeIdentifiers
        ) associatedApps
      );
    in
    {
      # custom.craftApps.<app>.enable / .setDefaultApplication / .mimeTypes / .uniformTypeIdentifiers
      options.custom.craftApps = lib.genAttrs appNames (
        appName:
        lib.mkOption {
          description = "ArtCraft ${appName} installation and file associations.";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to install ${appName}.";
              };
              setDefaultApplication = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether ${appName} becomes the default handler for its file types.";
              };
              mimeTypes = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = defaultAssociations.${appName}.mimeTypes;
                description = "MIME types opened with ${appName} by default on Linux.";
              };
              uniformTypeIdentifiers = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = defaultAssociations.${appName}.uniformTypeIdentifiers;
                description = "Uniform Type Identifiers opened with ${appName} by default on macOS.";
              };
            };
          };
        }
      );

      config = lib.mkMerge [
        {
          # Install every enabled app; the Linux packages ship desktop entries and MIME definitions.
          home.packages = lib.mapAttrsToList (appName: _appCfg: craftPackages.${appName}) enabledApps;
        }

        # Linux: point each claimed MIME type at the app's desktop entry.
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          xdg.mimeApps = {
            enable = true;
            defaultApplications = lib.mkMerge (
              lib.mapAttrsToList (
                appName: appCfg:
                lib.genAttrs appCfg.mimeTypes (_mimeType: [ craftPackages.${appName}.passthru.desktopFile ])
              ) associatedApps
            );
          };
        })

        # macOS: register the copied bundles, then set them as LaunchServices handlers.
        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          home.activation.craftAppsFileAssociations = lib.hm.dag.entryAfter [
            "copyApps"
          ] darwinAssociationCommands;
        })
      ];
    };
}
