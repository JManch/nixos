{
  lib,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib) ns;
  inherit (inputs) agenix nix-resources;
  inherit (config.${lib.ns}.system) impermanence;
  scriptInputs = [
    pkgs.fd
    pkgs.${ns}.bootstrap-kit
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
      for file in $(fd --base-directory "$bootstrap_kit" --absolute-path --type file --exclude "*.pub" "ssh_host_ed25519_key|agenix_ed25519_key"); do
        keys+=" -i $file"
      done

      if [[ ''${EDITOR:-} != "cp /dev/stdin" ]]; then
        export EDITOR=nano
      fi
    '';

  editSecretScript = pkgs.writeShellApplication {
    name = "agenix-edit";
    runtimeInputs = scriptInputs;
    text = ''
      if [[ $# -ne 1 ]]; then
        echo "Usage: agenix-edit <file_path>" >&2
        exit 1
      fi

      ${setup}

      eval agenix -e "$1" "$keys" < /dev/stdin
      chown 1000:100 ./*
    '';
  };

  rekeySecretScript = pkgs.writeShellApplication {
    name = "agenix-rekey";
    runtimeInputs = scriptInputs;
    text = ''
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

  ns.adminPackages = [
    agenix.packages.${pkgs.system}.default
    pkgs.${ns}.bootstrap-kit
    editSecretScript
    rekeySecretScript
  ];

  users.users.root.packages = [
    pkgs.${ns}.bootstrap-kit
    editSecretScript
    rekeySecretScript
  ];

  # Agenix decrypts before impermanence creates mounts so we have to get key
  # from persist
  age.identityPaths = [
    "${lib.optionalString impermanence.enable "/persist"}/etc/ssh/ssh_host_ed25519_key"
  ];
}
