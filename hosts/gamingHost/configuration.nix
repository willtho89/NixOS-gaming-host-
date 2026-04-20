{ config, lib, pkgs, gamingHostLocalSettings ? {}, ... }:

let
  settings = import ./settings.nix {
    inherit lib gamingHostLocalSettings;
  };
in
{
  imports = [
    ./hardware-configuration.nix # Generated during installation
    ../../modules/nvidia.nix
    ../../modules/gaming.nix
    ../../modules/airplay.nix
    ../../modules/sunshine.nix
    ../../modules/autoupgrade.nix
  ];

  # Nix and Nixpkgs settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Pass settings to all modules
  _module.args.settings = settings;

  # Bootloader. Use systemd-boot for modern UEFI systems.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = settings.hostname;
  networking.networkmanager.enable = true;

  # Enable OpenSSH for remote updates/management
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true; # Allow password auth initially
    openFirewall = true;
  };

  # Time and Locale
  time.timeZone = settings.timeZone;
  i18n = {
    defaultLocale = settings.defaultLocale;
    extraLocaleSettings = {
      LC_ADDRESS = settings.defaultLocale;
      LC_IDENTIFICATION = settings.defaultLocale;
      LC_MEASUREMENT = settings.defaultLocale;
      LC_MONETARY = settings.defaultLocale;
      LC_NAME = settings.defaultLocale;
      LC_NUMERIC = settings.defaultLocale;
      LC_PAPER = settings.defaultLocale;
      LC_TELEPHONE = settings.defaultLocale;
      LC_TIME = settings.defaultLocale;
    };
  };
  console.keyMap = settings.consoleKeyMap;
  services.xserver.xkb = {
    layout = settings.xkbLayout;
  };

  # AMD Ryzen specific settings
  hardware.cpu.amd.updateMicrocode = true;

  # User account
  users.users.${settings.username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" "render" "input" ];
    # Use a hashed password or change it via `passwd` after install
    initialPassword = settings.initialPassword;
    openssh.authorizedKeys.keys = settings.authorizedKeys;
  };

  security.sudo.wheelNeedsPassword = false;

  # Graphical Environment - KDE Plasma is great for gaming machine management
  # but we will default to Gamescope Session for the "Steam Machine" feel.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  
  # Auto-login for that "Console" experience
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = settings.username;
  services.displayManager.sddm.autoLogin.relogin = true;
  services.getty.autologinUser = settings.username;
  
  # Set default session to the Plasma session for a desktop experience
  # This can be changed back to the Steam Gamescope session in the login screen if needed.
  services.displayManager.defaultSession = "plasma";

  # Sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # System state version
  system.stateVersion = "25.11"; # This matches the current NixOS version
}
