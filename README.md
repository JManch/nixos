![blank-workspace](https://github.com/JManch/nixos/assets/61563764/88951964-f6aa-48b6-889b-48fa1a7d3e00)
![light-dark-split](https://github.com/JManch/nixos/assets/61563764/aa32d9df-42f8-4d39-a02b-653b40d03f4f)

## Overview

- Hyprland desktop environment integrated with systemd using UWSM
- Single-command deployment with Disko and NixOS Anywhere
- Fully modular configuration utilising NixOS module options
- Tmpfs root file system with opt-in persistence—no stateful cruft
- Persistent ZFS file system with full-disk encryption and compression
- Passwordless disk decryption with Secure Boot and TPM
- Declarative base-16 color scheme config with light/dark theme switching
- Secret management using Agenix (secrets stored in private repo)
- Declarative Restic backup system with remote redundancy

## Structure

All system and Home Manager modules are stored under the `modules` directory.
Options are used heavily to enable, disable, or modify modules on each host.
Each host has two entry points for module configuration:
`hosts/<hostname>/default.nix` for system configuration and
`homes/<hostname>.nix` for Home Manager configuration.

Modules are split into categories using directories. Each directory contains a
`default.nix` file which defines all options for modules in that category. The
benefits of this are that (1), modules avoid an extra layer of nesting for
`config = {}` and (2), `default.nix` serves as a convenient location to view
all options in a category.

## Deployment

Hosts can be deployed with a single command. There is no need to manually copy
SSH keys for secret deployment. All that's required is a master password.
Everything, including secrets, will be installed.

Run `build-iso` to get a custom install ISO. The ISO authenticates my SSH key
 and provides the install script `install-host <hostname>`.

The configuration also supports running a VM-variant of any host using `run-vm
<hostname>`. This enables easy debugging/testing of host configurations. It's
particularly useful for bisecting old versions of configurations to debug
regressions.

## Secret Management

Secrets are managed using Agenix and are stored in a separate private repo. A
private repo was required for storing personal packages and some slightly
sensitive configuration (not sensitive enough to require encryption).
Therefore, it was decided that secrets might as well be placed in the private
repo as well.

## Backups

Restic is utilised for a declarative and opt-in backup solution. Rather than
saving full system snapshots, specific paths are backed up on a per-module
basis to minimise the amount of redundant data in contingency storage. The
backup module has options for defining custom restore scripts and backup
scripts if necessary.
