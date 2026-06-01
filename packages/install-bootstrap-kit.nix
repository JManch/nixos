{
  writeShellApplication,
  coreutils,
  scopePkgs,
}:
writeShellApplication {
  name = "install-bootstrap-kit";

  runtimeInputs = [
    coreutils
    scopePkgs.bootstrap-kit
  ];

  text = ''
    if [[ $(id -u) != 0 ]]; then
       echo "install-bootstrap-kit must be run as root" >&2
       exit 1
    fi

    bootstrap_kit=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --root-dir)        root_dir="$2"; shift 2 ;;
        --username)        username="$2"; shift 2 ;;
        --admin-username)  admin_username="$2"; shift 2 ;;
        --hostname)        hostname="$2"; shift 2 ;;
        --bootstrap-kit)   bootstrap_kit="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
      esac
    done

    if [[ -z $rootDir ]]; then
      echo "Error: --root-dir must not be empty" >&2
      exit 1
    fi

    if [[ ! -d $rootDir ]]; then
      echo "Error: root dir '$root_dir' does not exist (is the target filesystem mounted?)" >&2
      exit 1
    fi

    if [[ -z $bootstrap_kit ]]; then
      echo "### Decrypting bootstrap-kit ###"
      bootstrap_kit=$(mktemp -d)
      trap 'rm -rf "$bootstrap_kit"' EXIT
      bootstrap-kit decrypt "$bootstrap_kit"
    fi

    echo "### Installing keys ###"
    install -d -m755 "$root_dir/etc/ssh" "$root_dir/etc/nix" "$root_dir/home"
    install -d -m700 "$root_dir/home/$username" "$root_dir/home/$admin_username"
    install -d -m700 "$root_dir/home/$username/.ssh" "$root_dir/home/$admin_username/.ssh"

    # Host keys
    mv "$bootstrap_kit/$hostname"/ssh_host_ed25519_key* "$root_dir/etc/ssh"

    # Nix store keys
    if [[ -f $bootstrap_kit/$hostname/nix_store_ed25519_key ]]; then
      mv "$bootstrap_kit/$hostname"/nix_store_ed25519_key* "$root_dir/etc/nix"
    fi

    # User keys
    if [[ -d $bootstrap_kit/$username ]]; then
      mv "$bootstrap_kit/$username"/* "$root_dir/home/$username/.ssh"
    fi

    # Admin user keys
    if [[ -d $bootstrap_kit/$admin_username && -n "$(ls -A "$bootstrap_kit/$admin_username")" ]]; then
      mv "$bootstrap_kit/$admin_username"/* "$root_dir/home/$admin_username/.ssh"
    fi

    # user:users
    chown -R 1000:100 "$root_dir/home/$username"

    if [[ $username != "$admin_username" ]]; then
      # admin_user:wheel
      chown -R 1:1 "$root_dir/home/$admin_username"
    fi
  '';
}
