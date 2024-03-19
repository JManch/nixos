{ pkgs, inputs, ... }:
let
  inherit (inputs) agenix nix-resources;
  scriptInputs = with pkgs; [
    age
    findutils
    agenix.packages.${pkgs.system}.agenix
    gnutar
  ];

  decryptKit = /*bash*/ ''
    temp=$(mktemp -d)
    cleanup() {
      rm -rf "$temp"
    }
    trap cleanup EXIT

    kit_path="${../../../hosts/ssh-bootstrap-kit}"
    age -d -o "$temp/ssh-bootstrap-kit.tar" "$kit_path"
    tar -xf "$temp/ssh-bootstrap-kit.tar" -C "$temp"
    rm -f "$temp/ssh-bootstrap-kit.tar";
  '';

  editSecretScript = pkgs.writeShellApplication {
    name = "agenix-edit";
    runtimeInputs = scriptInputs;
    text = /*bash*/ ''

      if [ -z "$1" ]; then
        echo "Usage: agenix-edit <file_path>"
        exit 1
      fi

      ${decryptKit}

      keys=""
      # shellcheck disable=SC2044
      for file in $(find "$temp" -type f -name "ssh_host_ed25519_key"); do
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
      for file in $(find "$temp" -type f -name "ssh_host_ed25519_key"); do
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

  environment.systemPackages = [
    agenix.packages.${pkgs.system}.default
    editSecretScript
    rekeySecretScript
  ];

  # Agenix decrypts before impermanence creates mounts so we have to get key
  # from persist
  age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
}
