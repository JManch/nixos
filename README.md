![blank-workspace](https://github.com/JManch/nixos/assets/61563764/88951964-f6aa-48b6-889b-48fa1a7d3e00)
![light-dark-split](https://github.com/JManch/nixos/assets/61563764/aa32d9df-42f8-4d39-a02b-653b40d03f4f)

## Overview

- Hyprland desktop environment integrated with systemd using UWSM
- Single-command deployment with a custom installer ISO and Disko
- Fully modular configuration utilizing NixOS module options
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

## Module wrapper

Modules are imported using a module wrapper `lib/module-wrapper.nix` that aims
to reduce boilerplate and enforce a strict structure for options under a custom
namespace.

To demonstrate how the wrapper works, here is a comparison of a module defined
with and without the wrapper. These two examples produce exactly the same
result.

**Without wrapper:**
```nix
# modules/nixos/services/example.nix
{ lib, config, inputs, ... }:
let
  cfg = config.${lib.ns}.services.example;
in
{
  imports = [ inputs.custom-flake.nixosModules.default ];

  options.${lib.ns}.services.example = {
    enable = lib.mkEnableOption "example";

    customOption = lib.mkOption {
      # ...
    };
  };

  config = lib.mkIf (cfg.enable && config.${lib.ns}.services.otherService.enable && config.program.example.enable) {
    assertions = [
      {
        assertion = config.${lib.ns}.services.serviceDependency.enable;
        message = "Module 'services.example' depends on module 'services.serviceDependency'";
      }
    ];

    services.example = {
      enable = true;
      option = cfg.customOption;
      # ...
    };

    ${lib.ns}.namespaceOption = "value";
  };
}
```

**With wrapper:**
```nix
# modules/nixos/services/example.nix
{ lib, cfg, config, inputs }:
{
  imports = [ inputs.custom-flake.nixosModules.default ];

  opts.customOption = lib.mkOption {
    # ...
  };

  conditions = [ "services.otherService" config.program.example.enable ];
  requirements = [ "services.serviceDependency" ];

  services.example = {
    enable = true;
    option = cfg.customOption;
    # ...
  };

  ns.namespaceOption = "value";
}
```

**Module wrapper improvements:**
- Config can be defined at the top-level next to things like `imports`
- Options defined under `opts` are automatically prefixed with the module's namespace
- No need to define `cfg` as it is provided as an argument
- No need to define an enable option and guard the module with it: this is done
automatically unless disabled with `enableOpt = false;`
- Additional module guards and assertions are easy to define with the
`conditions` and `requirements` lists

### Modules with Multiple Configuration Sets

For modules that consist of multiple configuration sets, the module wrapper
supports providing the module as a list. In this case guard behaviour is
controlled with the `guardType` option.

```nix
{ lib, cfg, pkgs }:
[
  {
    # Can be one of "full", "first", "custom"
    guardType = "first";

    opts.extraConfig = lib.mkEnableOption "extra config";

    services.example = {
      enable = true;
    };
  }

  (lib.mkIf cfg.extraConfig {
    programs.example.enable = true;
  })

  {
    # This config will be applied unconditionally as only the first set is guarded
    environment.systemPackages = [ pkgs.example ];
  }
]
```

For more information check `lib/module-system.nix` where all the custom wrapper
options are documented.
