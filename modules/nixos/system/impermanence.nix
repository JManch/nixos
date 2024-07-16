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
          # Unfortunately it isn't possible to persist individual state folders for
          # services using DynamicUser=yes. This is because systemd assigns
          # dynamic UIDs to users of this service so it's impossible to set the
          # required permissions with impermanence. Services place this dynamic
          # user folder in /var/lib/private/<service>. I will add commented out
          # persistence definitions in the relevant services so their files are
          # still documented.
          {
            directory = "/var/lib/private";
            mode = "0700";
          }
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
        directories = mkForce [ ];
        files = mkForce [ ];
        users.${username} = mkForce { };
      };
    })
  ];
}
