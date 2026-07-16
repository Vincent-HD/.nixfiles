#!/usr/bin/env bash
set -euo pipefail

readonly package_version="@version@"
readonly wine="@wine@"
readonly wineboot="@wineboot@"
readonly winecfg="@winecfg@"
readonly wineserver="@wineserver@"
readonly winetricks="@winetricks@"
readonly winetricks_wine="@winetricksWine@"
readonly find_command="@find@"
readonly login_helper="@loginHelper@"
readonly admin_installer="@adminInstaller@"
readonly webview2_installer="@webView2Installer@"
readonly dxvk="@dxvk@"
readonly machine_options="@options@"

readonly data_root="${FUSION360_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fusion360}"
readonly state_root="${FUSION360_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/fusion360}"
readonly marker="$state_root/installed-version"
readonly phase_root="$state_root/phases"
readonly winetricks_cache="$state_root/winetricks-cache"
export WINEARCH=win64
export WINEPREFIX="${FUSION360_WINEPREFIX:-$data_root/prefix}"
export W_CACHE="$winetricks_cache"
export WINE="$wine"
export WINEBOOT="$wineboot"
export WINESERVER="$wineserver"

latest_prefix_file() {
  local name="$1"
  local newest=""
  local candidate

  while IFS= read -r -d '' candidate; do
    if [[ -z "$newest" || "$candidate" -nt "$newest" ]]; then
      newest="$candidate"
    fi
  done < <("$find_command" "$WINEPREFIX" -type f -iname "$name" -print0 2>/dev/null)

  printf '%s' "$newest"
}

require_installation() {
  local launcher
  launcher="$(latest_prefix_file Fusion360.exe)"
  if [[ -z "$launcher" ]]; then
    echo "Fusion is not installed in $WINEPREFIX." >&2
    echo "Run fusion360-setup once from a graphical session." >&2
    exit 1
  fi
  printf '%s' "$launcher"
}

set_registry_value() {
  "$wine" reg add 'HKCU\Software\Wine\DllOverrides' /v "$1" /t REG_SZ /d "$2" /f
}

run_winetricks() {
  WINE="$winetricks_wine" \
    WINELOADER="$winetricks_wine" \
    WINESERVER="$wineserver" \
    "$winetricks" "$@"
}

stop_edge_updater() {
  # WebView2 registers an updater that can outlive unrelated installers and
  # prevent wineserver from reporting that all useful work has finished.
  "$wine" taskkill /F /IM MicrosoftEdgeUpdate.exe >/dev/null 2>&1 || true
}

install_dxvk() {
  local dll
  local system32="$WINEPREFIX/drive_c/windows/system32"
  local syswow64="$WINEPREFIX/drive_c/windows/syswow64"

  mkdir -p "$system32" "$syswow64"
  for dll in d3d10core d3d11 dxgi; do
    cp -f "$dxvk/x64/$dll.dll" "$system32/$dll.dll"
    cp -f "$dxvk/x32/$dll.dll" "$syswow64/$dll.dll"
    set_registry_value "*$dll" native
  done

  # Fusion's navigation bar works more reliably with Wine's built-in D3D9.
  set_registry_value '*d3d9' builtin
}

install_machine_options() {
  local wine_user="${USER:-user}"
  local user_root="$WINEPREFIX/drive_c/users/$wine_user"
  local relative='Autodesk/Neutron Platform/Options/NMachineSpecificOptions.xml'
  local destination

  for destination in \
    "$user_root/AppData/Roaming/$relative" \
    "$user_root/AppData/Local/$relative" \
    "$user_root/Application Data/$relative"; do
    mkdir -p "$(dirname "$destination")"
    cp -f "$machine_options" "$destination"
  done
}

run_setup() {
  local force=false
  case "${1:-}" in
    "") ;;
    --force) force=true ;;
    -h|--help)
      echo "Usage: fusion360-setup [--force]"
      echo "Initializes the Wine prefix and installs the pinned offline Fusion build."
      return
      ;;
    *)
      echo "Unknown option: $1" >&2
      return 2
      ;;
  esac

  if [[ -f "$marker" && "$force" == false ]]; then
    echo "Fusion setup already completed with package $(<"$marker")."
    echo "Use --force only to repair or refresh the existing prefix."
    return
  fi

  mkdir -p "$WINEPREFIX" "$state_root/logs" "$phase_root" "$winetricks_cache"
  exec > >(tee -a "$state_root/logs/setup.log") 2>&1
  export WINEDEBUG=-all,+err
  trap '"$wineserver" -k >/dev/null 2>&1 || true' EXIT

  echo "Preparing Fusion $package_version in $WINEPREFIX"
  echo "The winetricks phase downloads Microsoft redistributables with upstream checksums."
  if [[ "$force" == true || ! -f "$phase_root/wine-prefix" ]]; then
    "$wineboot" --init
    "$wineserver" -w
    touch "$phase_root/wine-prefix"
  else
    echo "Reusing the initialized Wine prefix"
  fi

  if [[ "$force" == true || ! -f "$phase_root/dependencies" ]]; then
    run_winetricks -q \
      atmlib \
      gdiplus \
      corefonts \
      cjkfonts \
      dotnet20 \
      dotnet48 \
      msxml4 \
      msxml6 \
      vcrun2022 \
      fontsmooth=rgb \
      winhttp \
      win10
    run_winetricks -q cjkfonts
    run_winetricks -q win11
    touch "$phase_root/dependencies"
  else
    echo "Reusing the installed winetricks dependencies"
  fi
  # The checked downloads are only needed during dependency installation.
  rm -rf "$winetricks_cache"

  if [[ "$force" == true || ! -f "$phase_root/registry" ]]; then
    # Match the DLL policy maintained by the active Fusion-on-Linux recipe.
    set_registry_value adpclientservice.exe native
    set_registry_value AdCefWebBrowser.exe builtin
    set_registry_value msvcp140 native
    set_registry_value mfc140u native
    set_registry_value bcp47langs ''
    "$wine" reg add 'HKCU\Software\Wine\X11 Driver' /v Managed /t REG_SZ /d Y /f
    "$wine" reg add 'HKCU\Software\Wine\X11 Driver' /v Decorated /t REG_SZ /d Y /f
    touch "$phase_root/registry"
  fi

  if [[ "$force" == true || ! -f "$phase_root/webview2" ]]; then
    echo "Installing the pinned WebView2 runtime"
    "$wine" "$webview2_installer" /silent /install

    # The Edge updater intentionally stays resident after WebView2 is ready,
    # so an unbounded wineserver wait never returns under Wine.
    if ! timeout --foreground -k 10s 2m "$wineserver" -w; then
      echo "WebView2 left its updater running; stopping the prefix after verification."
    fi
    if [[ -z "$(latest_prefix_file msedgewebview2.exe)" ]]; then
      echo "WebView2 installation did not produce msedgewebview2.exe." >&2
      return 1
    fi
    "$wineserver" -k
    touch "$phase_root/webview2"
  else
    echo "Reusing the installed WebView2 runtime"
  fi

  if [[ "$force" == true || ! -f "$phase_root/dxvk" ]]; then
    echo "Installing nixpkgs DXVK $dxvk"
    install_dxvk
    touch "$phase_root/dxvk"
  fi

  if [[ "$force" == true || ! -f "$phase_root/fusion" ]]; then
    echo "Installing the pinned Autodesk Fusion offline build"
    timeout --foreground -k 10m 45m "$wine" "$admin_installer" --quiet
    stop_edge_updater
    if ! timeout --foreground -k 30s 15m "$wineserver" -w; then
      echo "Fusion's installer left background processes running; stopping the prefix before validation."
      "$wineserver" -k
    fi

    if [[ -z "$(latest_prefix_file Fusion360.exe)" ]]; then
      echo "Fusion's first installer pass did not expose Fusion360.exe; running its finalization pass."
      timeout --foreground -k 5m 10m "$wine" "$admin_installer" --quiet
      stop_edge_updater
      if ! timeout --foreground -k 30s 5m "$wineserver" -w; then
        echo "Fusion's finalization pass left background processes running; stopping the prefix before validation."
        "$wineserver" -k
      fi
    fi
    require_installation >/dev/null
    touch "$phase_root/fusion"
  else
    echo "Reusing the installed Autodesk Fusion build"
  fi

  install_machine_options
  printf '%s\n' "$package_version" > "$marker"

  echo "Fusion $package_version setup completed. Start it with: fusion360"
}

run_fusion() {
  local launcher
  local identity_manager
  launcher="$(require_installation)"
  identity_manager="$(latest_prefix_file AdskIdentityManager.exe)"
  if [[ -z "$identity_manager" ]]; then
    echo "Autodesk Identity Manager is not installed in $WINEPREFIX." >&2
    return 1
  fi

  # Route Autodesk OAuth through the embedded Linux WebKitGTK helper. It
  # intercepts the adskidmgr callback and returns it to this exact prefix.
  "$wine" reg add 'HKCU\Software\Wine\WineBrowser' \
    /v Browsers /t REG_SZ /d "$login_helper" /f >/dev/null
  export FUSION360_WINE="$wine"
  export FUSION360_IDENTITY_MANAGER="$identity_manager"
  export DXVK_LOG_LEVEL=none
  export WINEDEBUG=-all,+err

  "$wine" "$launcher" "$@"
  "$wineserver" -k
}

handle_uri() {
  local identity_manager
  if [[ $# -ne 1 ]]; then
    echo "Usage: fusion360-uri-handler <adskidmgr-uri>" >&2
    return 2
  fi

  identity_manager="$(latest_prefix_file AdskIdentityManager.exe)"
  if [[ -z "$identity_manager" ]]; then
    echo "Autodesk Identity Manager is not installed in $WINEPREFIX." >&2
    return 1
  fi

  export WINEDEBUG=-all,+err
  exec "$wine" "$identity_manager" "$1"
}

diagnose() {
  echo "package-version=$package_version"
  echo "wine-version=$($wine --version)"
  echo "wine-prefix=$WINEPREFIX"
  echo "setup-marker=${marker}"
  echo "fusion-executable=$(latest_prefix_file Fusion360.exe)"
  echo "identity-manager=$(latest_prefix_file AdskIdentityManager.exe)"
  echo "login-helper=$login_helper"
}

case "${FUSION360_COMMAND:-${0##*/}}" in
  fusion360-setup) run_setup "$@" ;;
  fusion360-uri-handler) handle_uri "$@" ;;
  fusion360-winecfg) exec "$winecfg" ;;
  fusion360-diagnose) diagnose ;;
  fusion360) run_fusion "$@" ;;
  *)
    echo "Unsupported Fusion command name: ${0##*/}" >&2
    exit 2
    ;;
esac
