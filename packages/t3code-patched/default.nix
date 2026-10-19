{
  lib,
  runCommand,
  appimageTools,
  asar,
  t3code,
  t3code-web,
  enableUsagePatch ? true,
  enableJjPanel ? false,
}:
let
  # Keep the pinned Electron runtime and native modules while replacing selected app outputs.
  extracted =
    runCommand "t3code-${t3code.version}-custom-extracted"
      {
        nativeBuildInputs = [ asar ];
      }
      ''
        cp -R ${t3code.extracted} "$out"
        chmod -R u+w "$out"
        asar extract "$out/resources/app.asar" app
        test -f app/apps/server/dist/client/index.html
        cp app/apps/server/dist/client/third-party-licenses.json third-party-licenses.json
        ${lib.optionalString (enableUsagePatch || enableJjPanel) ''
          rm -r app/apps/server/dist
          cp -R ${t3code-web.server} app/apps/server/dist
          chmod -R u+w app/apps/server/dist
          test -f app/apps/server/dist/bin.mjs
        ''}
        rm -rf app/apps/server/dist/client
        cp -R ${t3code-web} app/apps/server/dist/client
        chmod -R u+w app
        cp third-party-licenses.json app/apps/server/dist/client/third-party-licenses.json
        rm "$out/resources/app.asar"
        rm -rf "$out/resources/app.asar.unpacked"
        asar pack app "$out/resources/app.asar" --unpack-dir 'node_modules'
        asar list "$out/resources/app.asar" > asar-files
        grep -Fx '/apps/server/dist/client/index.html' asar-files
      '';
in
assert t3code.version == t3code-web.version;
appimageTools.wrapAppImage {
  pname = "t3code";
  version = "${t3code.version}-custom";
  src = t3code.src;
  contents = extracted;
  extraPkgs = pkgs: [ pkgs.libsecret ];
  passthru.extracted = extracted;
  meta = t3code.meta // {
    description = "T3 Code nightly with selected local patches";
    platforms = [ "x86_64-linux" ];
  };
}
