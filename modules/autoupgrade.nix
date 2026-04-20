{ config, pkgs, lib, ... }:

{
  # Automatic System Upgrades
  # For a gaming desktop, we use the 'boot' operation to avoid interrupting sessions.
  # This builds the update in the background and applies it on the next boot.
  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    flake = "/etc/nixos#gamingHost";
    # Standard update check (fallback for when the machine is left on)
    dates = "04:00";
    randomizedDelaySec = "45min";
  };

  # Optimize the background upgrade service to avoid impacting games
  systemd.services.nixos-upgrade = {
    path = with pkgs; [ nix git coreutils gnugrep ];
    # Ensure inputs are updated before rebuilding
    preStart = ''
      cd /etc/nixos
      if [ -d .git ]; then
        ${pkgs.nix}/bin/nix flake update --commit-lock-file || ${pkgs.nix}/bin/nix flake update
      else
        ${pkgs.nix}/bin/nix flake update
      fi
    '';
    serviceConfig = {
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  # "Update on Shutdown" Trigger
  # This service ensures that when the user shuts down, the system checks for and
  # prepares updates so they are ready for the next startup.
  systemd.services.update-on-shutdown = {
    description = "Check for NixOS updates on shutdown";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    
    # Systemd stops services in reverse order of their 'After' dependencies.
    # We depend on network and nix-daemon so they are still up during ExecStop.
    after = [ "network-online.target" "nix-daemon.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Do nothing on start
      ExecStart = "${pkgs.coreutils}/bin/true";
      # On stop (shutdown or reboot), trigger the upgrade service.
      # We use 'boot' so the update is only applied during the next startup.
      # This satisfies the "update on shutdown" request by doing the heavy work 
      # after the user is finished with the machine.
      ExecStop = pkgs.writeShellScript "update-on-shutdown" ''
        echo "Checking for NixOS updates before powering off..."
        # If /etc/nixos exists, try to update it
        if [ -d /etc/nixos ]; then
          cd /etc/nixos
          # Update inputs (best effort)
          ${pkgs.nix}/bin/nix flake update --commit-lock-file || ${pkgs.nix}/bin/nix flake update || true
          # Rebuild and set as default for next boot
          ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake .#gamingHost || true
        else
          echo "/etc/nixos not found, skipping update on shutdown."
        fi
      '';
      TimeoutStopSec = "15min"; # Allow time for downloads/builds
    };
  };

  # Automatic Garbage Collection (Best Practice)
  # Prevents disk from filling up with old generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # Automatically deduplicate the Nix store to save space
  nix.settings.auto-optimise-store = true;
}
