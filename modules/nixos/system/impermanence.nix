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
      inherit (lib) getExe;
      fd = getExe pkgs.fd;
      extraExcludeDirs = [
        "root/.cache/nix"
        "home/${username}/.mozilla"
        "home/${username}/.cache/mozilla"
        "home/${username}/.local/share/chatterino/Cache"
      ];
    in
      /*bash*/ ''

      # Prints a list of all ephemeral system files
      impermanence() {
        sudo ${fd} --one-file-system --strip-cwd-prefix --base-directory / --type f \
          --hidden --exclude "{${concatStringsSep "," extraExcludeDirs}}" "''${@:1}"
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
