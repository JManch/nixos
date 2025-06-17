![blank-workspace](https://github.com/JManch/nixos/assets/61563764/88951964-f6aa-48b6-889b-48fa1a7d3e00)
![light-dark-split](https://github.com/JManch/nixos/assets/61563764/aa32d9df-42f8-4d39-a02b-653b40d03f4f)

## Overview

- Hyprland desktop environment integrated with systemd using UWSM
- Single-command deployment with a custom installer ISO and Disko
- Fully modular configuration utilising NixOS module options
- Tmpfs root with opt-in persistence using Impermanence
- Persistent ZFS file system with full-disk encryption and compression
- Passwordless disk decryption with Secure Boot and TPM
- Declarative base-16 color scheme config with light/dark theme switching
- Secret management using Agenix (secrets stored in private repo)
- Declarative backup system that supports multiple backends

## Structure

All system and Home Manager modules are stored under the `modules` directory.
Options are used heavily to enable, disable, or modify modules on each host.
Each host has two entry points for module configuration:
`hosts/<hostname>/default.nix` for system configuration and
`homes/<hostname>.nix` for Home Manager configuration.

Modules are imported using a wrapper `lib/module-wrapper.nix` that aims to
reduce boilerplate and enforce a strict structure for options under a custom
namespace.
