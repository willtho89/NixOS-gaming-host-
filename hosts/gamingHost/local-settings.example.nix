{ ... }:
{
  username = "your-username";
  hostname = "your-hostname";
  authorizedKeys = [
    "ssh-ed25519 AAAA... replace-me"
  ];

  # Optional overrides
  # initialPassword = "one-time-bootstrap-password";
  # sshPasswordAuthentication = true; # only if you need password-based SSH during bootstrap
  # wheelNeedsPassword = false; # convenience tradeoff, not recommended on shared networks
  # enableAutoLogin = true; # console-style appliance mode
  # enableTTYAutoLogin = true; # local TTY autologin
  # enableSunshine = true; # only enable when you actually use streaming
  # timeZone = "Europe/Berlin";
  # defaultLocale = "de_DE.UTF-8";
  # consoleKeyMap = "de";
  # xkbLayout = "de";
  # gamingMonitor = "DP-1";
}
