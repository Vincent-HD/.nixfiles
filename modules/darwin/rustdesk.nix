{ ... }:
{
  config.flake.modules.darwin.rustdesk =
    { ... }:
    {
      homebrew = {
        enable = true;
        casks = [ "rustdesk" ];
      };
    };
}
