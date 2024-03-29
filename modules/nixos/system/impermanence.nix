{ lib
, pkgs
, inputs
, username
, ...
} @ args:
let
  inherit (lib) utils mkAliasOptionModule concatStringsSep;
  homeManagerPersistence = (utils.homeConfig args).persistence;
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence

    (mkAliasOptionModule
      [ "persistenceHome" ]
      [ "environment" "persistence" "/persist" "users" username ])

    (mkAliasOptionModule
      [ "persistence" ]
      [ "environment" "persistence" "/persist" ])
  ];

  programs.zsh.interactiveShellInit =
    let
      inherit (lib) getExe getExe';
      fd = getExe pkgs.fd;
      sed = getExe pkgs.gnused;
      tr = getExe' pkgs.coreutils "tr";
      findmnt = getExe' pkgs.util-linux "findmnt";
      extraExcludeDirs = [
        "proc"
        "sys"
        "run"
        "dev"
        "tmp"
        "boot"
        "root/.cache/nix"
        "home/${username}/.mozilla"
        "home/${username}/.cache/mozilla"
      ];
    in
      /*bash*/ ''

      # Prints a list of all ephemeral system files
      impermanence() {
        # Get comma seperated list of zfs mounted directories and remove leading /
        exclude_dirs=$(${findmnt} -n -o TARGET --list -t zfs | ${sed} 's/^.//' | ${tr} '\n' ',' | ${sed} 's/.$//')
        exclude_dirs="$exclude_dirs,${concatStringsSep "," extraExcludeDirs}"
        # Get list of all files, excluding those with zfs mounted paths
        sudo ${fd} --base-directory / -a -tf -H -E "{$exclude_dirs}"
      }

    '';

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
      { directory = "/var/lib/private"; mode = "0700"; }
    ];

    files = [
      "/etc/machine-id"
      "/etc/adjtime"
    ];

    users.${username} = homeManagerPersistence;
  };
}
