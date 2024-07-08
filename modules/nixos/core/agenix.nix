{ lib
, pkgs
, config
, inputs
, adminUsername
, ...
}:
let
  inherit (inputs) agenix nix-resources;
  inherit (config.modules.system) impermanence;
  scriptInputs = (with pkgs; [
    age
    findutils
    gnutar
  ]) ++ [ agenix.packages.${pkgs.system}.agenix ];

  decryptKit = /*bash*/ ''
    temp=$(mktemp -d)
    cleanup() {
      rm -rf "$temp"
    }
    trap cleanup EXIT

    kit_path="${../../../hosts/ssh-bootstrap-kit}"
    age -d "$kit_path" | tar -xf - -C "$temp"
  '';

  editSecretScript = pkgs.writeShellApplication {
    name = "agenix-edit";
    runtimeInputs = scriptInputs;
    text = /*bash*/ ''
      if [ "$#" -ne 1 ]; then
        echo "Usage: agenix-edit <file_path>"
        exit 1
      fi

      ${decryptKit}

      keys=""
      # shellcheck disable=SC2044
      for file in $(find "$temp" -type f ! -name "*.pub"); do
        keys+=" -i $file"
      done

      eval agenix -e "$1" "$keys"
    '';
  };

  rekeySecretScript = pkgs.writeShellApplication {
    name = "agenix-rekey";
    runtimeInputs = scriptInputs;
    text = /*bash*/ ''
      ${decryptKit}

      keys=""
      # shellcheck disable=SC2044
      for file in $(find "$temp" -type f ! -name "*.pub"); do
        keys+=" -i $file"
      done

      eval agenix -r "$keys"
    '';
  };
in
{
  imports = [
    agenix.nixosModules.default
    nix-resources.nixosModules.secrets
  ];

  users.users.${adminUsername}.packages = [
    agenix.packages.${pkgs.system}.default
    editSecretScript
    rekeySecretScript
  ];

  # Agenix decrypts before impermanence creates mounts so we have to get key
  # from persist
  age.identityPaths = [ "${lib.optionalString impermanence.enable "/persist"}/etc/ssh/ssh_host_ed25519_key" ];
}
