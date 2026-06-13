{
  description = "NixOS configuration for a high-end gaming host";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    # Official hardware modules for best practices
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs:
    let
      envLocalSettingsPath = builtins.getEnv "GAMING_HOST_SETTINGS_PATH";
      pwd = builtins.getEnv "PWD";
      hostLocalSettingsPath = /etc/nixos/hosts/gamingHost/local-settings.nix;
      inferredLocalSettingsPath =
        if pwd == "" then
          null
        else
          /. + "${pwd}/hosts/gamingHost/local-settings.nix";
      localSettingsPath =
        if envLocalSettingsPath != "" then
          if builtins.substring 0 1 envLocalSettingsPath != "/" then
            throw "GAMING_HOST_SETTINGS_PATH must be an absolute path"
          else
            /. + envLocalSettingsPath
        else if builtins.pathExists hostLocalSettingsPath then
          hostLocalSettingsPath
        else if inferredLocalSettingsPath != null && builtins.pathExists inferredLocalSettingsPath then
          inferredLocalSettingsPath
        else
          null;
      localSettingsError = ''
        Missing gamingHost local settings.

        Create hosts/gamingHost/local-settings.nix from hosts/gamingHost/local-settings.example.nix,
        or set GAMING_HOST_SETTINGS_PATH to an absolute path.
      '';
      gamingHostLocalSettings =
        if localSettingsPath == null then
          throw localSettingsError
        else
          import localSettingsPath { lib = nixpkgs.lib; };
    in
    {
      nixosConfigurations.gamingHost = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs gamingHostLocalSettings;
        };
        modules = [
          # Base hardware modules from nixos-hardware
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-pc-ssd

          ./hosts/gamingHost/configuration.nix
        ];
      };

      # Custom installer ISO configuration
      # This creates a minimal NixOS installer that already has your SSH keys.
      # Build it with: nix build .#nixosConfigurations.installer.config.system.build.isoImage
      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ({ ... }: {
            networking.networkmanager.enable = true;
            services.openssh.enable = true;

            # Reuse SSH keys from your gamingHost settings for the installer
            users.users.nixos.openssh.authorizedKeys.keys =
              (import ./hosts/gamingHost/settings.nix {
                lib = nixpkgs.lib;
                inherit gamingHostLocalSettings;
              }).authorizedKeys;
          })
        ];
      };
    };
}
