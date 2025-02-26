{
  lib,
  pkgs,
  config,
  inputs,
  selfPkgs,
}:
let
  inherit (inputs) agenix nix-resources;
  inherit (config.${lib.ns}.system) impermanence;
  scriptInputs = [
    pkgs.findutils
    selfPkgs.bootstrap-kit
    agenix.packages.${pkgs.system}.agenix
  ];

  setup = # bash
    ''
      if [[ $(id -u) != 0 ]]; then
         echo "agenix script must be run as root" >&2
         exit 1
      fi

      if [[ $PWD != */nix-resources/secrets ]]; then
         echo "agenix script must be run in secrets dir of nix-resources" >&2
         exit 1
      fi

      bootstrap_kit=$(mktemp -d)
      cleanup() {
        rm -rf "$bootstrap_kit"
      }
      trap cleanup EXIT

      bootstrap-kit decrypt "$bootstrap_kit"

      keys=""
      # shellcheck disable=SC2044
      for file in $(find "$bootstrap_kit" -type f ! -name "*.pub"); do
        keys+=" -i $file"
      done

      export EDITOR=nano
    '';

  editSecretScript = pkgs.writeShellApplication {
    name = "agenix-edit";
    runtimeInputs = scriptInputs;
    text = # bash
      ''
        if [[ $# -ne 1 ]]; then
          echo "Usage: agenix-edit <file_path>" >&2
          exit 1
        fi

        ${setup}

        eval agenix -e "$1" "$keys"
        chown 1000:100 ./*
      '';
  };

  rekeySecretScript = pkgs.writeShellApplication {
    name = "agenix-rekey";
    runtimeInputs = scriptInputs;
    text = # bash
      ''
        ${setup}
        eval agenix -r "$keys"
        chown 1000:100 ./*
      '';
  };
in
{
  imports = [
    agenix.nixosModules.default
    nix-resources.nixosModules.secrets
  ];

  enableOpt = false;

  adminPackages = [
    selfPkgs.bootstrap-kit
    agenix.packages.${pkgs.system}.default
    editSecretScript
    rekeySecretScript
  ];

  # Agenix decrypts before impermanence creates mounts so we have to get key
  # from persist
  age.identityPaths = [
    "${lib.optionalString impermanence.enable "/persist"}/etc/ssh/ssh_host_ed25519_key"
  ];
}
