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
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Keep builds parallel without oversubscribing evaluation itself.
    max-jobs = 4;
    cores = 0;
  };
  nixpkgs.config.allowUnfree = true;

  # Give local rebuilds some breathing room on machines without disk swap.
  zramSwap.enable = true;

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
    settings = {
      PasswordAuthentication = settings.sshPasswordAuthentication;
      KbdInteractiveAuthentication = settings.sshPasswordAuthentication;
      PermitRootLogin = "no";
    };
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
    openssh.authorizedKeys.keys = settings.authorizedKeys;
  } // lib.optionalAttrs (settings.initialPassword != null) {
    initialPassword = settings.initialPassword;
  };

  security.sudo.wheelNeedsPassword = settings.wheelNeedsPassword;

  # Graphical Environment - KDE Plasma remains the default desktop session.
  # The Steam Gamescope session is also available from the login screen.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  
  # Optional auto-login for an appliance-style setup.
  services.displayManager.autoLogin.enable = settings.enableAutoLogin;
  services.displayManager.autoLogin.user = settings.username;
  services.displayManager.sddm.autoLogin.relogin = settings.enableAutoLogin;
  
  # Plasma is the default session; Steam Gamescope can be selected in SDDM.
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

  # Set this once when the machine is first installed; do not bump casually.
  system.stateVersion = "25.11";
}

// lib.optionalAttrs settings.enableTTYAutoLogin {
  services.getty.autologinUser = settings.username;
}
