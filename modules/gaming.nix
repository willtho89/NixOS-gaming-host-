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

  gaminghostUpdateSystem = pkgs.writeShellApplication {
    name = "gaminghost-update-system";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nix
      nixos-rebuild
      sudo
    ];
    text = ''
      set -euo pipefail

      cd /etc/nixos

      if [ -d .git ]; then
        branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'main')"
        upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || printf 'origin/%s' "$branch")"

        printf '\n==> Syncing repository from %s...\n' "$upstream"
        git fetch --all --prune
        git reset --hard "$upstream"
        git clean -fd
      else
        printf '\n==> /etc/nixos is not a git checkout; skipping repository sync.\n'
      fi

      printf '\n==> Updating flake inputs...\n'
      sudo nix flake update

      printf '\n==> Applying updated system...\n'
      if sudo nixos-rebuild switch --impure --flake .#gamingHost; then
        printf '\nUpdate finished. Reboot is recommended when the kernel, graphics driver, or core services changed.\n'
      else
        printf '\nSwitch failed, staging the update for the next boot instead...\n'
        sudo nixos-rebuild boot --impure --flake .#gamingHost
        printf '\nUpdate staged for next boot. Please reboot to finish applying it.\n'
      fi

      printf 'You can close this window now.\n'
      read -r -p 'Press Enter to exit...'
    '';
  };

  gaminghostUpdateDesktopItem = pkgs.makeDesktopItem {
    name = "gaminghost-update-system";
    desktopName = "Update System and Packages";
    genericName = "NixOS system updater";
    comment = "Pull the repo, update flake inputs, and rebuild this gaming host";
    exec = "gaminghost-update-system";
    terminal = true;
    categories = [ "System" "Settings" ];
    icon = "system-software-update";
  };

in
{
  # Steam configuration
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraProfile = ''
        if [ "''${SteamAppId:-}" = "3768760" ]; then
          export PROTON_VKD3D_HEAP=1
          export VKD3D_CONFIG=no_async_compute,no_upload_hvv
          export VKD3D_DISABLE_EXTENSIONS=VK_EXT_mesh_shader,VK_NV_raw_access_chains
        fi
      '';
      extraLibraries = p: with p; [
        freetype
      ];
    };
    # Open ports in the firewall for Steam Remote Play
    remotePlay.openFirewall = true;
    # Open ports for Steam local network transfers.
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
    codex
    gamescope
    opencode
    pavucontrol
    protonup-qt # Manage Proton-GE versions easily
    bottles # For non-Steam games/launchers
    pulseaudio
    steam-run # Useful for running random binaries
    vim
    vkbasalt # Vulkan post-processing layer

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
    gaminghostUpdateSystem
    gaminghostUpdateDesktopItem
  ];

  system.activationScripts.gaminghostDesktopShortcut = lib.stringAfter [ "users" ] ''
    desktop_dir="/home/${settings.username}/Desktop"
    desktop_file="$desktop_dir/Update System and Packages.desktop"
    mkdir -p "$desktop_dir"
    cp ${gaminghostUpdateDesktopItem}/share/applications/gaminghost-update-system.desktop "$desktop_file"
    chown ${settings.username}:users "$desktop_file"
    chmod 0755 "$desktop_file"
  '';

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
