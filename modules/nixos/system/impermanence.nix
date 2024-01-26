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

  programs.zsh.shellAliases = {
    # Form a list of all files of the system and exclude file paths that
    # contain ZFS mounts. Remaining files will just be those that are not
    # mounted in someway to /persist
    impermanence =
      let
        fd = "${pkgs.fd}/bin/fd";
        findmnt = "${pkgs.util-linux}/bin/findmnt";
        sed = "${pkgs.gnused}/bin/sed";
        tr = "${pkgs.coreutils}/bin/tr";
        excludeDirs = "proc,sys,run,dev,tmp,boot,root/.cache/nix";
      in
      ''
        sudo ${fd} --base-directory / -a -tf -H -E \
        "{$(${findmnt} -n -o TARGET --list -t zfs | ${sed} 's/^.//' | ${tr} '\n' ',' | ${sed} 's/.$//'),${excludeDirs}}"
      '';
  };

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
