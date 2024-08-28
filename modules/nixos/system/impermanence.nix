{
  lib,
  pkgs,
  config,
  inputs,
  username,
  adminUsername,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    mkMerge
    utils
    mkAliasOptionModule
    concatStringsSep
    hasAttr
    ;
  inherit (config.modules.core) homeManager;
  inherit (config.modules.system.virtualisation) vmVariant;
  cfg = config.modules.system.impermanence;
  homePersistence = config.home-manager.users.${username}.persistence;
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence

    (mkAliasOptionModule [ "persistence" ] [
      "environment"
      "persistence"
      "/persist"
    ])

    (mkAliasOptionModule [ "persistenceHome" ] [
      "environment"
      "persistence"
      "/persist"
      "users"
      username
    ])

    (mkAliasOptionModule [ "persistenceAdminHome" ] [
      "environment"
      "persistence"
      "/persist"
      "users"
      adminUsername
    ])
  ];

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = utils.asserts [
        (vmVariant || (hasAttr "/persist" config.fileSystems))
        "A /persist file system must be defined for impermanence"
      ];

      programs.zsh.interactiveShellInit =
        let
          inherit (lib) getExe;
          fd = getExe pkgs.fd;
          extraExcludeDirs = [
            "tmp"
            "root/.cache/nix"
            "home/${username}/.mozilla"
            "home/${username}/.cache/mozilla"
            "home/${username}/.local/share/chatterino/Cache"
            "home/${username}/.config/darkman/variants"
          ];
        in
        # bash
        ''
          # Prints a list of all ephemeral system files
          impermanence() {
            sudo ${fd} --one-file-system --strip-cwd-prefix --base-directory / --type f \
              --hidden --exclude "{${concatStringsSep "," extraExcludeDirs}}" "''${@:1}"
          }
        '';

      fileSystems."/persist".neededForBoot = true;

      persistence = {
        hideMounts = true;

        directories = [
          "/var/log"
          "/var/tmp"
          "/var/lib/systemd"
          "/var/lib/nixos"
          "/var/db/sudo/lectured"
          # WARN: Systemd services that use DynamicUser without defining a
          # static User and Group cannot be persisted as it's impossible to
          # preallocated the correct UID/GID. It should be possible to work
          # around this by adding User= and Group= to DynamicUser services and
          # also declaratively creating the User and Group
        ];

        files = [
          "/etc/machine-id"
          "/etc/adjtime"
        ];

        users.${username} = mkIf homeManager.enable homePersistence;
      };
    })

    (mkIf (!cfg.enable) {
      persistence = {
        enable = false;
        directories = mkForce [ ];
        files = mkForce [ ];
        users.${username} = mkForce { };
      };
    })
  ];
}
