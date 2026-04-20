{ config, lib, pkgs, settings, ... }:

let
  # This script is designed for KDE Plasma 6 (Wayland) using kscreen-doctor.
  # It should be used as Sunshine's global_prep_cmd (do) and undo_prep_cmd (undo).
  # Required environment variables from Sunshine:
  # SUNSHINE_CLIENT_WIDTH, SUNSHINE_CLIENT_HEIGHT, SUNSHINE_CLIENT_FPS, SUNSHINE_CLIENT_HDR_ENABLED
  sunshine-display-prep = pkgs.writeShellApplication {
    name = "sunshine-display-prep";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      kdePackages.libkscreen
    ];
    text = ''
      set -euo pipefail

      ACTION="''${1:-}"
      TARGET_MONITOR="${settings.gamingMonitor}"
      STATE_FILE="/tmp/sunshine_display_state_$USER.json"

      # Log to a file for troubleshooting
      LOG_FILE="/tmp/sunshine_display_prep_$USER.log"
      exec >> "$LOG_FILE" 2>&1
      echo "--- $(date): Action: $ACTION, Target: $TARGET_MONITOR ---"

      case "$ACTION" in
          do)
              # 1. Save current state
              kscreen-doctor -j > "$STATE_FILE"
              
              # 2. Extract client params or use sensible defaults
              WIDTH="''${SUNSHINE_CLIENT_WIDTH:-1920}"
              HEIGHT="''${SUNSHINE_CLIENT_HEIGHT:-1080}"
              FPS="''${SUNSHINE_CLIENT_FPS:-60}"
              HDR="''${SUNSHINE_CLIENT_HDR_ENABLED:-0}"
              
              echo "Requested: ''${WIDTH}x''${HEIGHT}@''${FPS}, HDR: $HDR"
              
              # 3. Get all connected outputs
              ALL_OUTPUTS=$(jq -r '.outputs[].name' "$STATE_FILE")
              
              CMD="kscreen-doctor"
              TARGET_FOUND=false
              for output in $ALL_OUTPUTS; do
                  if [[ "$output" == "$TARGET_MONITOR" ]]; then
                      TARGET_FOUND=true
                      # Enable and set mode
                      CMD="$CMD output.$output.enable output.$output.mode.''${WIDTH}x''${HEIGHT}@''${FPS} output.$output.priority.1"
                      
                      # Handle HDR and WCG
                      if [[ "$HDR" == "1" ]]; then
                          CMD="$CMD output.$output.hdr.enable output.$output.wcg.enable"
                      else
                          CMD="$CMD output.$output.hdr.disable output.$output.wcg.disable"
                      fi
                  else
                      # Disable all other monitors
                      CMD="$CMD output.$output.disable"
                  fi
              done
              
              if [[ "$TARGET_FOUND" == "false" ]]; then
                  echo "Error: Target monitor $TARGET_MONITOR not found among outputs: $ALL_OUTPUTS"
                  exit 1
              fi
              
              echo "Running: $CMD"
              eval "$CMD"
              ;;
              
          undo)
              if [[ -f "$STATE_FILE" ]]; then
                  echo "Restoring display state from $STATE_FILE"
                  
                  # Restore each output's state (enabled/disabled, mode, priority, HDR)
                  # Note: currentModeId in kscreen-doctor JSON is what .mode. expects.
                  RESTORE_ARGS=$(jq -r '.outputs | .[] | "output." + .name + (if .enabled then " .enable .mode." + .currentModeId + " .priority." + (.priority|tostring) + (if .hdr.enabled then " .hdr.enable .wcg.enable" else " .hdr.disable .wcg.disable" end) else " .disable" end)' "$STATE_FILE" | tr '\n' ' ')
                  
                  echo "Restoring with args: $RESTORE_ARGS"
                  eval "kscreen-doctor $RESTORE_ARGS"
                  
                  rm "$STATE_FILE"
              else
                  echo "No state file found, nothing to restore."
              fi
              ;;
          *)
              echo "Usage: $0 <do|undo>"
              exit 1
              ;;
      esac
    '';
  };
in
{
  # Enable Sunshine streaming server
  services.sunshine = {
    enable = true;
    autoStart = true; # Start on boot
    capSysAdmin = true; # Required for some features
    openFirewall = true; # Automatically open required ports
  };

  # Override the Sunshine systemd user service to use our declarative config
  # We set the WorkingDirectory to the user's config folder so Sunshine can still save its apps.json there.
  systemd.user.services.sunshine = {
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.sunshine}/bin/sunshine /etc/sunshine/sunshine.conf";
      WorkingDirectory = "%h/.config/sunshine";
    };
  };

  # Provide the configuration that uses the prep script
  environment.etc."sunshine/sunshine.conf".text = ''
    global_prep_cmd = [{"do":"${sunshine-display-prep}/bin/sunshine-display-prep do","undo":"${sunshine-display-prep}/bin/sunshine-display-prep undo"}]
    # Force use of the correct output if needed
    # output_name = 1
  '';

  # Ensure necessary tools are available in the system
  environment.systemPackages = with pkgs; [
    jq
    kdePackages.libkscreen # provides kscreen-doctor
    sunshine-display-prep
  ];

  # Extra firewall rules just in case or for Moonlight specific features
  networking.firewall = {
    allowedTCPPorts = [ 47984 47989 48010 ];
    allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];
  };

  # Sunshine needs uinput to simulate inputs
  boot.kernelModules = [ "uinput" ];
  
  # Ensure udev rules for uinput are set for the sunshine user/group
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';
}
