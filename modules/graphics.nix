{ ... }:
{
  # NixOS side: NVIDIA GPU
  config.flake.modules.nixos.graphics =
    { pkgs, ... }:
    let
      lactSettings = builtins.fromJSON (builtins.readFile ./graphics/assets/lact-settings.json);
    in
    {
      hardware.graphics.enable = true;
      hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open = true;

      # Provide the local LACT daemon and GUI for controlled NVIDIA tuning.
      services.lact.enable = true;
      # Keep the MSI curve in the source asset, but omit it from generated YAML because Nix
      # serializes its numeric curve keys as strings, which LACT rejects.
      services.lact.settings = lactSettings // {
        profiles = builtins.removeAttrs lactSettings.profiles [ "msi-profile1-safe" ];
      };

      # NVIDIA VA-API driver for hardware video decode in browsers/Electron apps
      # https://github.com/elFarto/nvidia-vaapi-driver
      environment = {
        systemPackages = [ pkgs.libva-utils ];
        variables = {
          LIBVA_DRIVER_NAME = "nvidia";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          NVD_BACKEND = "direct";
        };
      };
    };

  # Home Manager side: reapply the tested profile after the user session starts.
  config.flake.modules.homeManager.graphics =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      profileFile = "${config.home.homeDirectory}/.config/lact/community-typical.json";
      applyProfile = pkgs.writeShellApplication {
        name = "lact-apply-community-typical";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          exec ${pkgs.python3}/bin/python3 - <<'PY'
          import json
          import os
          import socket
          import time

          gpu_id = "10DE:2208-10DE:1535-0000:2b:00.0"
          profile_path = os.environ["LACT_PROFILE_FILE"]

          def request(sock, payload):
              sock.sendall((json.dumps(payload) + "\n").encode())
              data = b""
              while b"\n" not in data:
                  chunk = sock.recv(65536)
                  if not chunk:
                      raise RuntimeError("LACT socket closed")
                  data += chunk
              response = json.loads(data.split(b"\n", 1)[0])
              if response.get("status") != "ok":
                  raise RuntimeError(response)
              return response.get("data")

          settings = json.loads(open(profile_path, encoding="utf-8").read())
          profile = settings["profiles"]["community-typical"]["gpus"][gpu_id]

          for attempt in range(30):
              try:
                  with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                      sock.settimeout(10)
                      sock.connect("/run/lactd.sock")
                      current = request(sock, {"command": "get_gpu_config", "args": {"id": gpu_id}})
                      if not isinstance(current, dict):
                          raise RuntimeError("LACT returned no GPU configuration")
                      current = dict(profile)
                      request(sock, {"command": "set_gpu_config", "args": {"id": gpu_id, "config": current}})
                      request(sock, {"command": "confirm_pending_config", "args": {"command": "confirm"}})
                  print("Applied community-typical through LACT")
                  break
              except (OSError, RuntimeError) as error:
                  if attempt == 29:
                      raise
                  print(f"Waiting for LACT ({error})")
                  time.sleep(2)
          PY
        '';
      };
    in
    {
      home.file.".config/lact/community-typical.json".source = ./graphics/assets/lact-settings.json;
      home.packages = [ applyProfile ];

      systemd.user.services.lact-profile-community-typical = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit = {
          Description = "Apply the typical RTX 3080 Ti FE LACT profile";
          After = [ "graphical-session.target" ];
          # Re-run the applier whenever the profile asset content changes; without a
          # trigger the generated unit is unchanged and the previous profile stays
          # active. Hash the content so unrelated repository edits do not restart it.
          X-Restart-Triggers = [
            (builtins.hashString "sha256" (builtins.readFile ./graphics/assets/lact-settings.json))
          ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = [ "${applyProfile}/bin/lact-apply-community-typical" ];
          Environment = [ "LACT_PROFILE_FILE=${profileFile}" ];
          RemainAfterExit = true;
          TimeoutStartSec = 90;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
