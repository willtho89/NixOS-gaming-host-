{ config, lib, pkgs, settings ? {}, ... }:

let
  sonosAceAudioFix = pkgs.writeShellApplication {
    name = "sonos-ace-audio-fix";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gawk
      pulseaudio
      wireplumber
    ];
    text = ''
      set -eu

      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      get_id_for_line() {
        awk '
          match($0, /([0-9]+)\./) {
            print substr($0, RSTART, RLENGTH - 1)
            exit
          }
        '
      }

      device_id=""
      for _ in $(seq 1 30); do
        device_id="$(wpctl status | awk '/Sonos Ace \(USB\)[[:space:]]+\[alsa\]/{print}' | get_id_for_line || true)"
        if [ -n "$device_id" ]; then
          break
        fi

        device_id="$(wpctl status | awk '/USB Audio[[:space:]]+\[alsa\]/{print}' | get_id_for_line || true)"
        if [ -n "$device_id" ]; then
          break
        fi
        sleep 1
      done

      if [ -z "$device_id" ]; then
        exit 0
      fi

      sink_id=""
      sink_name=""

      # Prefer the Sonos analog stereo sink when present.
      sink_id="$(wpctl status | awk '/Audio Speaker Analog Stereo/{print}' | get_id_for_line || true)"

      if [ -n "$sink_id" ]; then
        # Sonos Ace exposes an "analog-stereo" profile.
        wpctl set-profile "$device_id" 1 || true
        sink_name="alsa_output.usb-Sonos__Inc._Sonos_Ace__USB__000000000010-00.analog-stereo"
      else
        # Fallback for the generic USB audio presentation.
        wpctl set-profile "$device_id" 1 || true
        sleep 1
        sink_id="$(wpctl status | awk '/USB Audio Front Headphones/{print}' | get_id_for_line || true)"
        if [ -z "$sink_id" ]; then
          sink_id="$(wpctl status | awk '/USB Audio Speakers/{print}' | get_id_for_line || true)"
        fi
        if [ -z "$sink_id" ]; then
          exit 0
        fi
        sink_name="$(wpctl inspect "$sink_id" | awk -F'"' '/node.name =/{print $2; exit}')"
      fi

      wpctl set-default "$sink_id" || true

      if [ -z "$sink_name" ]; then
        sink_name="$(wpctl inspect "$sink_id" | awk -F'"' '/node.name =/{print $2; exit}')"
      fi
      if [ -n "$sink_name" ]; then
        pactl list short sink-inputs 2>/dev/null | awk '{print $1}' | while read -r input_id; do
          pactl move-sink-input "$input_id" "$sink_name" || true
        done
      fi
    '';
  };

  # A small wrapper script to start Steam with environment checks
  # This avoids the "Unable to open a connection to X" error during autostart
  steamAutostart = pkgs.writeShellScriptBin "steam-autostart" ''
    # Wait up to 30 seconds for a display to be available in the systemd user session
    # and for the X server to be actually accepting connections.
    LOG="/tmp/steam-autostart.log"
    echo "Starting steam-autostart at $(date)" > "$LOG"
    
    for i in {1..60}; do
      ENV=$(systemctl --user show-environment)
      if echo "$ENV" | grep -E -q "^(WAYLAND_DISPLAY|DISPLAY)="; then
        echo "Found display variables in systemd environment at attempt $i" >> "$LOG"
        
        # Export relevant environment variables from systemd to this process
        while read -r line; do
          if [[ "$line" =~ ^(DISPLAY|WAYLAND_DISPLAY|XDG_RUNTIME_DIR|XAUTHORITY|XDG_SESSION_TYPE|XDG_CURRENT_DESKTOP|KDE_FULL_SESSION|GBM_BACKEND|NVD_BACKEND|__GLX_VENDOR_LIBRARY_NAME|LIBVA_DRIVER_NAME)= ]]; then
            echo "Exporting $line" >> "$LOG"
            export "$line"
          fi
        done <<EOF
$ENV
EOF

        # If we have a DISPLAY, wait for it to be actually functional
        if [ -n "''${DISPLAY:-}" ]; then
          if ${pkgs.xrandr}/bin/xrandr >/dev/null 2>&1; then
            echo "X display is ready and functional. Launching Steam." >> "$LOG"
            exec steam -silent "$@"
          else
            echo "X display is set but not yet functional (xrandr failed)." >> "$LOG"
          fi
        else
          # If we only have WAYLAND_DISPLAY, Steam will start Xwayland anyway
          echo "Only Wayland display found. Launching Steam." >> "$LOG"
          exec steam -silent "$@"
        fi
      fi
      sleep 0.5
    done
    
    echo "Timed out waiting for functional display. Launching Steam anyway as fallback." >> "$LOG"
    exec steam -silent "$@"
  '';
in
{
  # Steam configuration
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraLibraries = p: with p; [
        freetype
      ];
    };
    # Open ports in the firewall for Steam Remote Play
    remotePlay.openFirewall = true;
    # Open ports in the firewall for Steam Local Network Game Transfers
    dedicatedServer.openFirewall = true;
    # Enable the Steam display-manager session that launches through Gamescope
    # This remains available as an option in the login screen.
    gamescopeSession = {
      enable = true;
      # Force gamescope to use the correct monitor
      args = [
        "-O" "${settings.gamingMonitor}"
      ];
    };
  };

  # Autostart Steam in the background (minimized) when the graphical session starts
  # We use a wrapper script to ensure the display environment is ready.
  # We also restrict it to common desktop environments to avoid running in the gamescope session.
  environment.etc."xdg/autostart/steam.desktop".text = ''
    [Desktop Entry]
    Name=Steam
    Comment=Application for managing and playing games on Steam
    Exec=steam-autostart
    Icon=steam
    Terminal=false
    Type=Application
    Categories=Network;FileTransfer;Game;
    OnlyShowIn=KDE;GNOME;XFCE;
  '';

  # Enable gamescope compositor with cap_sys_nice for better performance
  programs.gamescope.enable = true;

  # Gamemode for performance optimizations
  programs.gamemode.enable = true;
  programs.firefox.enable = true;

  # Gaming-related system packages
  environment.systemPackages = with pkgs; [
    alsa-utils
    # Monitoring and overlays
    mangohud
    goverlay # UI for MangoHud

    # Compatibility and performance
    bitwarden-desktop
    gamescope
    pavucontrol
    protonup-qt # Manage Proton-GE versions easily
    bottles # For non-Steam games/launchers
    pulseaudio
    steam-run # Useful for running random binaries
    vkbasalt # Vulkan post-processing layer
    steamAutostart

    # Debug tools for displays
    wlr-randr
    xrandr
    psmisc # For killall

    # Allow Steam Big Picture to switch back to the desktop
    (pkgs.writeShellScriptBin "steamos-session-select" ''
      # If plasma is selected, we just kill steam to end the current gamescope session.
      # Since sddm is set to auto-login to plasma by default, this will return us to the desktop.
      if [[ "$1" == "plasma" ]]; then
        pkill -u $USER -9 steam
      fi
    '')
  ];

  # Better controller support
  hardware.bluetooth.enable = true;
  hardware.xpadneo.enable = true;
  services.blueman.enable = true; # GUI for bluetooth

  # Enable udev rules for controllers
  hardware.steam-hardware.enable = true;

  services.pipewire.wireplumber.extraConfig."90-sonos-ace" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "device.name" = "alsa_card.usb-Sonos__Inc._Sonos_Ace__USB__000000000010-00";
          }
        ];
        actions.update-props = {
          "device.description" = "Sonos Ace (USB)";
          "device.nick" = "Sonos Ace (USB)";
        };
      }
      {
        matches = [
          {
            "node.name" = "alsa_output.usb-Sonos__Inc._Sonos_Ace__USB__000000000010-00.analog-stereo";
          }
        ];
        actions.update-props = {
          "node.description" = "Sonos Ace (USB)";
          "node.nick" = "Sonos Ace (USB)";
        };
      }
      {
        matches = [
          {
            "node.name" = "alsa_input.usb-Sonos__Inc._Sonos_Ace__USB__000000000010-00.analog-stereo";
          }
        ];
        actions.update-props = {
          "node.description" = "Sonos Ace (USB) Microphone";
          "node.nick" = "Sonos Ace (USB) Microphone";
        };
      }
    ];
  };

  systemd.user.services.sonos-ace-audio-fix = {
    description = "Prefer Sonos Ace headphone output over SPDIF";
    after = [ "graphical-session.target" "pipewire.service" "wireplumber.service" ];
    wants = [ "graphical-session.target" "pipewire.service" "wireplumber.service" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      Environment = [ "XDG_RUNTIME_DIR=%t" ];
      ExecStart = "${sonosAceAudioFix}/bin/sonos-ace-audio-fix";
    };
  };
  
  # Optimization for gaming: increase file handle limits
  security.pam.loginLimits = [{
    domain = "*";
    type = "soft";
    item = "nofile";
    value = "1048576";
  } {
    domain = "*";
    type = "hard";
    item = "nofile";
    value = "1048576";
  }];
}
