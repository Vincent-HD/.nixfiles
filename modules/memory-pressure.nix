{
  config.flake.modules.nixos.memoryPressure =
    { ... }:
    {
      # Use compressed RAM swap so temporary memory spikes degrade gracefully instead of hard-freezing.
      zramSwap.enable = true;
      zramSwap.algorithm = "zstd";
      zramSwap.memoryPercent = 100;
      zramSwap.priority = 100;

      # Kill runaway memory users early enough that the desktop can stay responsive.
      services.earlyoom.enable = true;
      services.earlyoom.enableNotifications = true;
      services.earlyoom.freeMemThreshold = 5;
      services.earlyoom.freeSwapThreshold = 10;
      services.earlyoom.freeMemKillThreshold = 2;
      services.earlyoom.freeSwapKillThreshold = 5;
    };
}
