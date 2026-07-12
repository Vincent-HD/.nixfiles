{ ... }:
{
  config.flake.modules.homeManager.codingNixTools =
    { pkgs, lib, ... }:
    let
      nixswitch = pkgs.writeShellScriptBin "nixswitch" ''
        case "$(uname -s)" in
          Darwin)
            exec sudo darwin-rebuild switch --flake "$HOME/.nixfiles#macbook-pro"
            ;;
          Linux)
            exec sudo nixos-rebuild switch --flake "$HOME/.nixfiles#pc-fixe"
            ;;
          *)
            echo "Unsupported operating system: $(uname -s)" >&2
            exit 1
            ;;
        esac
      '';
    in
    {
      home.packages = [
        nixswitch
        pkgs.nil
        pkgs.nixfmt
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        pkgs.mcp-nixos
      ];
    };
}
