<h1 align="center">JManch/nixos</h1>

![blank-workspace](https://github.com/JManch/nixos/assets/61563764/e073392b-7be3-425c-a2b1-30a7d7c323f2)
![populated-workspace](https://github.com/JManch/nixos/assets/61563764/4df158f9-8122-45e9-bab1-24ab87998ec5)

# Features

- Fully modular for easy configuration of multiple hosts
- ZFS file system with encryption and compression
- Opt-in persistence with root dir as tmpfs
- Customised Hyprland desktop environment
- System-wide base-16 colorscheme management
- Disko and nixos-anywhere for fast deployment
- Secret management using agenix

# Installation
Run `build-iso` to get a custom install ISO. The ISO authenticates my SSH key for remote installs and provides an install script for installing locally.
- Remote: `deploy-host <hostname> <ip_address>`
- Local: `install-host <hostname>` inside the ISO
