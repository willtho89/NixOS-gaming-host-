{ config, pkgs, lib, ... }:

{
  # Automatic System Upgrades
  # For a gaming desktop, use the 'boot' operation to avoid interrupting sessions.
  # This rebuilds from the currently pinned flake revision and applies it on the next boot.
  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    flake = "/etc/nixos#gamingHost";
    flags = [ "--impure" ];
    dates = "04:00";
    randomizedDelaySec = "45min";
  };

  # Optimize the background upgrade service to avoid impacting games.
  systemd.services.nixos-upgrade = {
    serviceConfig = {
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  # Prevent the store from filling up with old generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # Automatically deduplicate the Nix store to save space
  nix.settings.auto-optimise-store = true;
}
