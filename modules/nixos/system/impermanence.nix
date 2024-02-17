{ lib
, pkgs
, inputs
, username
, ...
} @ args:
let
  homeManagerPersistence = (lib.utils.homeConfig args).persistence;
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  programs.zsh.interactiveShellInit =
    let
      fd = "${pkgs.fd}/bin/fd";
      findmnt = "${pkgs.util-linux}/bin/findmnt";
      sed = "${pkgs.gnused}/bin/sed";
      tr = "${pkgs.coreutils}/bin/tr";
      extraExcludeDirs = "proc,sys,run,dev,tmp,boot,root/.cache/nix";
    in
      /* bash */ ''
      impermanence() {
        # Prints a list of all files that are not persisted by impermanence so will be lost on shutdown

        # Get comma seperated list of zfs mounted directories and remove leading /
        exclude_dirs=$(${findmnt} -n -o TARGET --list -t zfs | ${sed} 's/^.//' | ${tr} '\n' ',' | ${sed} 's/.$//')
        exclude_dirs="$exclude_dirs,${extraExcludeDirs}"
        # Get list of all files, excluding those with zfs mounted paths
        sudo ${fd} --base-directory / -a -tf -H -E "{$exclude_dirs}"
      }
    '';

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/tmp"
      "/var/lib/systemd"
      "/var/lib/nixos"
      "/var/db/sudo/lectured"
      # Unfortunately it isn't possible to persist individual state folders for
      # services using DynamicUsers=yes. This is because systemd assigns
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
    # Take this config from our home-manager module
    users.${username} = homeManagerPersistence;
  };
}
