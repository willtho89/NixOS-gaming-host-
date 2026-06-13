{ lib, gamingHostLocalSettings ? {}, ... }:

let
  localSettings = gamingHostLocalSettings;
  allowBootstrapDefaults = localSettings.allowBootstrapDefaults or false;
  requireLocalSetting = name:
    if builtins.hasAttr name localSettings then
      builtins.getAttr name localSettings
    else
      throw "hosts/gamingHost/local-settings.nix must define `${name}`. Set allowBootstrapDefaults = true only for temporary bootstrap use.";
in
{
  # Default settings - Change these or create a local-settings.nix
  hostname = localSettings.hostname or "gamingHost";
  username = if allowBootstrapDefaults then (localSettings.username or "nixos") else requireLocalSetting "username";
  
  # Optional bootstrap password for first login.
  # Prefer SSH keys and leave this unset when possible.
  initialPassword = localSettings.initialPassword or null;

  # SSH Authorized Keys
  # Replace with your own public keys in local-settings.nix
  authorizedKeys = if allowBootstrapDefaults then (localSettings.authorizedKeys or [ ]) else requireLocalSetting "authorizedKeys";

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
