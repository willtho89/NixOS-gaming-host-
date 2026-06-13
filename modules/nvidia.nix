{ config, ... }:

{
  # Enable OpenGL/Vulkan (now renamed to hardware.graphics)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption after sleep.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Prefer the proprietary kernel module for Proton/DX12 stability.
    open = false;

    # Enable the Nvidia settings menu,
	# accessible via `nvidia-settings`.
    nvidiaSettings = false;

    # 007 First Light hits an NVIDIA 595-series Xid 109 timeout bug on Linux.
    # Track nixpkgs' latest packaged NVIDIA driver now that it includes 610.43.02+.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  # Wayland specific tweaks for Nvidia
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct"; # Use direct backend for VA-API on Nvidia
    ELECTRON_OZONE_PLATFORM_HINT = "auto"; # Better wayland support for Electron apps
  };
}
