{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  username,
  adminUsername,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    getExe
    mkAliasOptionModule
    concatMapStringsSep
    hasAttr
    ;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.system.virtualisation) vmVariant;
  homePersistence = config.${ns}.hmNs.persistence;
  fd = getExe pkgs.fd;

  # Print all files in the tmpfs file system that will be lost on shutdown
  ephemeralFinder =
    let
      excludePaths = [
        "/tmp"
        "/root/.cache/nix"
        "/home/${username}/.mozilla"
        "/home/${username}/.cache"
        "/home/${username}/.local/share/chatterino/Cache"
        "/home/${username}/.local/share/darkman/variants"
      ];
    in
    pkgs.writeShellScriptBin "impermanence-ephemeral" ''
      sudo ${fd} --unrestricted --one-file-system --absolute-path --base-directory / --type file \
        ${concatMapStringsSep " " (path: "--exclude \"${path}\"") excludePaths} "''${@:1}"
    '';

  # Prints all files and directories in the persistent file system that are not
  # defined as persistent in config
  bloatFinder =
    let
      excludePaths = [
        "/var/nix-tmp"
        "/home/${username}/.mozilla"
      ]
      ++ map (p: p.filePath) config.${ns}.persistence.files
      ++ map (p: p.dirPath) config.${ns}.persistence.directories;
    in
    pkgs.writeShellScriptBin "impermanence-bloat" ''
      sudo ${fd} --unrestricted --absolute-path --base-directory /persist --type file --type symlink \
        ${concatMapStringsSep " " (path: "--exclude \"${path}\"") excludePaths} "''${@:1}"

      # Another pass for empty dirs
      sudo ${fd} --unrestricted --absolute-path --base-directory /persist --type empty --type dir \
        ${concatMapStringsSep " " (path: "--exclude \"${path}\"") excludePaths} "''${@:1}"
    '';
in
[
  {
    guardType = "first";

    imports = [
      inputs.impermanence.nixosModules.impermanence

      (mkAliasOptionModule
        [ ns "persistence" ]
        [
          "environment"
          "persistence"
          "/persist"
        ]
      )

      (mkAliasOptionModule
        [ ns "persistenceHome" ]
        [
          "environment"
          "persistence"
          "/persist"
          "users"
          username
        ]
      )

      (mkAliasOptionModule
        [ ns "persistenceAdminHome" ]
        [
          "environment"
          "persistence"
          "/persist"
          "users"
          adminUsername
        ]
      )
    ];

    asserts = [
      (vmVariant || (hasAttr "/persist" config.fileSystems))
      "A /persist file system must be defined for impermanence"
      (vmVariant || (hasAttr "/nix" config.fileSystems))
      "A /nix file system must be defined for impermanence"
    ];

    ns.adminPackages = [
      ephemeralFinder
      bloatFinder
    ];

    fileSystems."/persist".neededForBoot = true;

    ns.persistence = {
      hideMounts = true;

      directories = [
        "/srv"
        "/var/log"
        "/var/tmp"
        "/var/lib/systemd"
        "/var/lib/nixos"
        "/var/db/sudo/lectured"
        # WARN: Systemd services that use DynamicUser without defining a
        # static User and Group cannot be persisted as it's impossible to
        # preallocated the correct UID/GID. It should be possible to work
        # around this by declaratively creating a user and group for the
        # service and using them for User and Group in the service's exec
        # config.
      ];

      files = [
        "/etc/machine-id"
        "/etc/adjtime"
      ];

      users.${username} = mkIf home-manager.enable homePersistence;
    };
  }

  (mkIf (!cfg.enable) {
    ns.persistence = {
      enable = false;
      directories = mkForce [ ];
      files = mkForce [ ];
      users.${username} = mkForce { };
    };
  })
]
