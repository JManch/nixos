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
    any
    hasPrefix
    ;
  inherit (config.${ns}.system.virtualisation) vmVariant;
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
        # Systemd services with DynamicUser=yes store state under
        # /var/lib/private/<StateDirectory>. Because these services dynamically allocate a
        # UID/GID every time they're started, we should create the persistent dir with
        # ownership nobody:nogroup. This allows systemd to create id-mapped mounts that
        # make the directory appear with correct ownership inside the service's
        # namespace. I do not think this is strictly necessary as systemd will chown
        # the dir if the ownership is incorrect but chowning can be an expensive
        # operation if there are many files and we'd rather avoid this with id-mapping.
      ];

      files = [
        "/etc/machine-id"
        "/etc/adjtime"
      ];
    };

    # Workaround for ensuring that /var/lib/private is created with the correct
    # permissions if a subdirectory is persisted
    # https://github.com/nix-community/impermanence/issues/254#issuecomment-2683859091
    system.activationScripts =
      mkIf (any (p: hasPrefix "/var/lib/private" p.dirPath) config.${ns}.persistence.directories)
        {
          "createVarLibPrivate" = {
            deps = [ "specialfs" ];
            text = ''
              mkdir -p /persist/var/lib/private
              chmod 0700 /persist/var/lib/private
            '';
          };

          "createPersistentStorageDirs".deps = [
            "createVarLibPrivate"
            "users"
            "groups"
          ];
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
