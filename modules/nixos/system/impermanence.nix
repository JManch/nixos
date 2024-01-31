{ lib
, pkgs
, inputs
, username
, ...
} @ args:
let
  homeManagerImpermanence = (lib.utils.homeConfig args).impermanence;
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  programs.zsh.shellInit =
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
    ];
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/machine-id"
      "/etc/adjtime"
    ];
    # Take this config from our home-manager module
    users.${username} = homeManagerImpermanence;
  };
}
