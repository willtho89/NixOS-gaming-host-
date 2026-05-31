{ lib, gamingHostLocalSettings ? {}, ... }:

let
  localSettings = gamingHostLocalSettings;
in
{
  # Default settings - Change these or create a local-settings.nix
  hostname = localSettings.hostname or "gamingHost";
  username = localSettings.username or "nixos"; # Change to your preferred username
  
  # Optional bootstrap password for first login.
  # Prefer SSH keys and leave this unset when possible.
  initialPassword = localSettings.initialPassword or null;

  # SSH Authorized Keys
  # Replace with your own public keys in local-settings.nix
  authorizedKeys = localSettings.authorizedKeys or [
    # "ssh-rsa AAAAB3NzaC1..." 
  ];

  # Harden defaults for a networked host.
  sshPasswordAuthentication = localSettings.sshPasswordAuthentication or false;
  wheelNeedsPassword = localSettings.wheelNeedsPassword or true;
  enableAutoLogin = localSettings.enableAutoLogin or false;
  enableTTYAutoLogin = localSettings.enableTTYAutoLogin or false;
  enableSunshine = localSettings.enableSunshine or false;

  # Time and Locale
  timeZone = localSettings.timeZone or "Europe/Berlin";
  defaultLocale = localSettings.defaultLocale or "de_DE.UTF-8";
  consoleKeyMap = localSettings.consoleKeyMap or "de";
  xkbLayout = localSettings.xkbLayout or "de";

  # Gaming Monitor for Gamescope session (e.g., "DP-1", "HDMI-A-1")
  # Use `wlr-randr` or `xrandr` to find the correct name.
  gamingMonitor = localSettings.gamingMonitor or "DP-1";
}
