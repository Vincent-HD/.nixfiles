{ ... }:
{
  config.flake.modules.darwin.rustdesk =
    { ... }:
    {
      homebrew = {
        enable = true;
        casks = [ "rustdesk" ];

        onActivation = {
          cleanup = "none";
          autoUpdate = false;
          upgrade = false;
          extraEnv.HOMEBREW_NO_ANALYTICS = "1";
        };
      };
    };
}
