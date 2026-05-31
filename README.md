# NixOS Gaming Host (2026 Edition)

This repository contains a modular NixOS configuration optimized for a high-end gaming PC featuring an **Nvidia RTX 4080** and an **AMD Ryzen CPU**. It defaults to **KDE Plasma 6** while also offering a **Steam Gamescope** session from the login screen.

## Features
- **Nvidia 4080 Optimized**: Uses the latest `open` kernel module and `fbdev=1` for smooth Wayland boot.
- **Desktop + Console Modes**: Defaults to Plasma, with the `steam` display-manager session available for a Steam Deck-like experience when wanted.
- **Sunshine/Moonlight Support**: Pre-configured for low-latency game streaming to other devices.
- **AMD Ryzen Performance**: Enabled microcode updates and `kvm-amd` support.
- **Portability Layers**: Includes Steam (Proton), `ProtonUp-Qt`, and `Bottles`.
- **Pinned Auto-Rebuilds**: Configured to rebuild daily from the currently pinned flake revision using the `boot` method, so the next boot picks up the prepared generation.

---

## 🛠️ Fresh Installation Guide

Follow these steps to install this configuration on a new machine:

### 0. (macOS) Create Custom Installer ISO
Since you are likely on a Mac, you need a remote builder to create the `x86_64-linux` ISO.

#### 0.1 Prepare Nix for Remote Building
If you get a warning about `restricted setting 'builders'` and you are not a trusted user, you need to add yourself to the `trusted-users` list in your Nix configuration.

Run this command on your Mac:
```bash
echo "trusted-users = $(whoami) root" | sudo tee -a /etc/nix/nix.custom.conf && sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

#### 0.2 Build the ISO
1. **Build the ISO** using the remote host (e.g., `builder.example.net`):
   ```bash
   nix build .#nixosConfigurations.installer.config.system.build.isoImage \
     --builders "ssh://builder.example.net x86_64-linux" \
     --max-jobs 1 \
     --eval-store auto
   ```
2. **Identify your USB drive**:
   ```bash
   diskutil list
   ```
   Assume it is `/dev/disk4`.
3. **Flash the ISO**:
   ```bash
   # Unmount the disk first
   diskutil unmountDisk /dev/disk4
   
   # Flash using dd (rdisk is faster)
   sudo dd if=result/iso/*.iso of=/dev/rdisk4 bs=1m status=progress
   ```

### 1. Boot from NixOS Installer
Download the latest NixOS ISO from [nixos.org](https://nixos.org/download.html) (or use your custom ISO from step 0) and boot your machine from a USB drive.

### 2. Partition and Format Disks
Format your disks as needed. For example:
```bash
# Example for a single NVMe drive with EFI and root
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart root ext4 512MiB 100%

sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2

# Mount them
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

### 3. Copy Configuration Files
Copy the contents of this repository to `/mnt/etc/nixos/`.

### 4. Configure Your Identity
Before installing or deploying, customize the user and hostname in `hosts/gamingHost/local-settings.nix`.

To keep your personal information (like your real username and SSH keys) out of Git, you can create a `local-settings.nix` file in the same directory. This file is already in `.gitignore` and will override the defaults in `settings.nix`.

Start from the committed example file:

```bash
cp hosts/gamingHost/local-settings.example.nix hosts/gamingHost/local-settings.nix
```

Because this repository currently uses an impure local-settings import, gitignored files are only visible during evaluation when you run with `--impure`. If you run commands from the repository root, the flake will automatically load `hosts/gamingHost/local-settings.nix`. You can also point to a different file with `GAMING_HOST_SETTINGS_PATH=/absolute/path/to/local-settings.nix`.

`local-settings.nix` stays out of Git, but `deploy.sh` will copy it to `/etc/nixos/hosts/gamingHost/local-settings.nix` on the gaming host before rebuilding.

Example `hosts/gamingHost/local-settings.nix`:
```nix
{ ... }:
{
  username = "your-username";
  hostname = "your-hostname";
  authorizedKeys = [
    "ssh-ed25519 AAAA... replace-me"
  ];
  # Optional bootstrap-only settings:
  # initialPassword = "one-time-bootstrap-password";
  # sshPasswordAuthentication = true;
  # enableAutoLogin = true;
  # enableSunshine = true;
}
```

### 5. Final Install
Execute the installation:
```bash
nixos-install --impure --flake /mnt/etc/nixos/#gamingHost
```

---

## 🔄 Updating the Host

### Local Update
To update the system directly from the gaming machine:
```bash
cd /etc/nixos
sudo nixos-rebuild switch --impure --flake .#gamingHost
```

### Remote Update (from Mac/another machine)
You can deploy updates from your Mac over SSH using the provided `deploy.sh` script. This script:

- refreshes `/etc/nixos` on the gaming host from the GitHub repo configured as your local `origin`
- copies your local gitignored `hosts/gamingHost/local-settings.nix` to the host
- handles cross-architecture builds by offloading the build to your gaming machine (useful when updating from an ARM Mac to an x86_64 PC)

```bash
# Run the deployment (it will use the default IP and user)
./deploy.sh gaming-pc.local

# Or specify a different host or username:
./deploy.sh 192.0.2.10 alice
```

If you prefer to run the command manually:
```bash
DEPLOY_USER="alice"
DEPLOY_HOST="gaming-pc.local"

nix run nixpkgs#nixos-rebuild -- \
  --no-reexec \
  switch \
  --impure \
  --flake ".#gamingHost" \
  --build-host "${DEPLOY_USER}@${DEPLOY_HOST}" \
  --target-host "${DEPLOY_USER}@${DEPLOY_HOST}" \
  --sudo
```

### Host-Side Self-Update Button
The desktop shortcut **Update System and Packages** does this on the gaming host:

1. resets `/etc/nixos` to the latest commit from its tracked Git branch
2. runs `nix flake update`
3. rebuilds the system with `switch`, or falls back to `boot` if a live switch is blocked

This means Git-tracked config comes from GitHub, while `local-settings.nix` continues to come from your latest `deploy.sh` run.

---

## 💡 Post-Installation Tips

### 1. Set Your Password
If you set `initialPassword` in `hosts/gamingHost/local-settings.nix` for bootstrap access, log in and change it immediately:
```bash
passwd
```

### 2. Configure Sunshine (Streaming)
Sunshine is disabled by default. Enable it in `hosts/gamingHost/local-settings.nix` when needed:

```nix
enableSunshine = true;
```

Access the Sunshine web UI to pair your Moonlight client:
- **URL**: `https://localhost:47990` (or the machine's IP address)
- **Login**: Use the credentials you set during the first run in the web UI.

### 3. Install Proton-GE
Open **ProtonUp-Qt** from the application menu (or search in Desktop mode) to install the latest **Proton-GE** for your Steam games.

### 4. Switching to Desktop Mode
While in the Steam Big Picture UI, go to the **Power** menu and select **Exit to Desktop**. This will take you to a full KDE Plasma 6 desktop environment.

### 5. Automatic Updates
The system is configured to stay up-to-date automatically:
- **Background Rebuild**: A daily task rebuilds the system from the currently pinned flake revision using low CPU and I/O priority.
- **Next Boot Activation**: Updates use the `boot` operation, meaning the prepared generation becomes active on the next startup.
- **Pin First, Deploy Second**: Update `flake.lock` intentionally, then let the host rebuild that pinned revision.
- **Clean Up**: Old generations older than 7 days are automatically removed weekly to save disk space.

---

## What To Commit

Commit:

- `flake.nix`
- `flake.lock`
- `README.md`
- `deploy.sh`
- `hosts/gamingHost/configuration.nix`
- `hosts/gamingHost/hardware-configuration.nix`
- `hosts/gamingHost/settings.nix`
- `hosts/gamingHost/local-settings.example.nix`
- `modules/`

Do not commit:

- `hosts/gamingHost/local-settings.nix`
- unencrypted secrets
- tool-state files such as `.junie/`
- ad hoc machine-specific files that are not meant to be shared
