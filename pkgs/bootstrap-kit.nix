{
  nix-resources,
  writeShellApplication,
  tree,
  gnutar,
  age,
  bootstrapKit ? "${nix-resources}/secrets/bootstrap-kit.tar.age",
}:
writeShellApplication {
  name = "bootstrap-kit";
  excludeShellChecks = [ "SC2064" ];

  runtimeInputs = [
    tree
    gnutar
    age
  ];

  text = ''
    if [[ $(id -u) != 0 ]]; then
       echo "Bootstrap kit management must be run as root" >&2
       exit 1
    fi

    if [[ $# -ne 2 ]] || [[ $1 != "encrypt" && $1 != "decrypt" ]]; then
      echo "Usage: bootstrap-kit <encrypt|decrypt> <input_dir|output_dir>" >&2
      exit 1
    fi

    if [[ -z $2 || ! -d $2 ]]; then
      echo "Invalid input/output directory" >&2
      exit 1
    fi

    encrypt() {
      local input_dir="$1"

      echo "The following files in $input_dir will be encrypted:"
      tree --noreport "$input_dir"
      echo -n "Press Enter to continue..."
      read -r

      local encrypt_tmp
      encrypt_tmp=$(mktemp -d)
      chmod og-rwx "$encrypt_tmp"
      trap "rm -rf '$encrypt_tmp'" EXIT

      cp -r "$input_dir"/* "$encrypt_tmp"

      local output_dir
      output_dir=$(mktemp -d)

      tar -cpO -C "$encrypt_tmp" . | age -e -p -o "$output_dir/bootstrap-kit.tar.age"

      chmod 755 "$output_dir"
      chmod 644 "$output_dir/bootstrap-kit.tar.age"

      rm -rf "$input_dir"
      echo "Encrypted bootstrap kit: $output_dir/bootstrap-kit.tar.age"
    }

    decrypt() {
      local output_dir="$1"

      if [[ -z $(find "$output_dir" -maxdepth 0 -empty) ]]; then
        echo "Output directory must be empty" >&2
        exit 1
      fi

      # Do not use root:root here because in our installer we need to run in an
      # activation script before users+groups are setup
      chown 0:0 "$output_dir"
      chmod og-rwx "$output_dir"

      trap "rm -rf '$output_dir'" EXIT

      kit="''${BOOTSTRAP_KIT:-${bootstrapKit}}"
      while ! age -d "$kit" | tar --same-owner -xpf - -C "$output_dir"; do
        true
      done

      trap - EXIT
      echo "Decrypted bootstrap kit in: $output_dir"
    }

    if [[ $1 == "encrypt" ]]; then
      encrypt "''${@:2}"
    elif [[ $1 == "decrypt" ]]; then
      decrypt "''${@:2}"
    fi
  '';
}
