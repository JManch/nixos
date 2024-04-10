{ lib
, pkgs
, outputs
, username
, hostname
, ...
}:
let
  inherit (lib) utils concatStrings getExe;

  deployScript = pkgs.writeShellApplication {
    name = "deploy-host";
    runtimeInputs = with pkgs; [
      age
      # nixos-anywhere does not allow passing extra flags to the nix build commands
      # so we have to patch it. The patch overrides our 'firstBoot' flake input to
      # 'true' so that we can change certain config options for the very first
      # build of a system. This is useful for options like secure boot that need
      # extra configuration to work.
      # This patch also preserves the file ownership in the rsync command used
      # for extra-files transfer. This is needed for deploying secrets to the
      # home directory.
      (pkgs.nixos-anywhere.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [ ../../../patches/nixosAnywhere.patch ];
      }))
      gnutar
    ];
    text = /*bash*/ ''

      if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: deploy-host <hostname> <ip_address>"
        exit 1
      fi

      hosts=(${lib.concatStringsSep " " (builtins.attrNames (utils.hosts outputs))})
      hostname=$1
      ip_address=$2

      match=0
      for host in "''${hosts[@]}"; do
        if [[ $host = "$hostname" ]]; then
          match=1
          break
        fi
      done
      if [[ $match = 0 ]]; then
        echo "Error: Host '$hostname' does not exist" >&2
        exit 1
      fi

      secret_temp=$(mktemp -d)
      temp=$(mktemp -d)
      cleanup() {
        rm -rf "$secret_temp"
        sudo rm -rf "$temp"
      }
      trap cleanup EXIT
      install -d -m755 "$temp/persist/etc/ssh"
      install -d -m755 "$temp/persist/home"
      install -d -m700 "$temp/persist/home/${username}"
      install -d -m700 "$temp/persist/home/${username}/.ssh"
      install -d -m755 "$temp/persist/home/${username}/.config"

      kit_path="${../../../hosts/ssh-bootstrap-kit}"
      age -d "$kit_path" | tar -xf - -C "$secret_temp"
      mv "$secret_temp/$hostname"/* "$temp/persist/etc/ssh"
      mv "$secret_temp/id_ed25519" "$temp/persist/home/${username}/.ssh"
      mv "$secret_temp/id_ed25519.pub" "$temp/persist/home/${username}/.ssh"
      mv "$secret_temp"/${username}/* "$temp/persist/home/${username}/.ssh"
      rm -rf "$secret_temp"

      cp -r /home/${username}/.config/nixos "$temp/persist/home/${username}/.config/nixos"

      sudo chown -R root:root "$temp/persist"
      sudo chown -R ${username}:users "$temp/persist/home"

      nixos-anywhere --extra-files "$temp" --flake "/home/${username}/.config/nixos#$hostname" "root@$ip_address"
      sudo rm -rf "$temp"

    '';
  };
in
{
  # Nvd has to be installed system wide to enable the remote host diff script
  # calling nvd over ssh
  environment.systemPackages = [ pkgs.nvd deployScript ];

  programs.zsh =
    let
      configDir = "/home/${username}/.config/nixos";
      nvd = getExe pkgs.nvd;
    in
    {
      enable = true;

      shellAliases = {
        rebuild-switch = "sudo nixos-rebuild switch --flake ${configDir}#${hostname}";
        rebuild-test = "sudo nixos-rebuild test --flake ${configDir}#${hostname}";
        rebuild-boot = "sudo nixos-rebuild boot --flake ${configDir}#${hostname}";
        # Go to home dir here because I once had a bad experience where I
        # accidentally built in /nix/store and caused irrepairable corruption
        rebuild-build = "pushd ~ >/dev/null && nixos-rebuild build --flake ${configDir}#${hostname}; popd >/dev/null";
        rebuild-dry-build = "nixos-rebuild dry-build --flake ${configDir}#${hostname}";
        rebuild-dry-activate = "sudo nixos-rebuild dry-activate --flake ${configDir}#${hostname}";
        rebuild-diff = "pushd ~ >/dev/null && rebuild-build && ${nvd} diff /run/current-system result; popd >/dev/null";
        build-iso = "nix build ${configDir}#nixosConfigurations.installer.config.system.build.isoImage";
      };

      interactiveShellInit =
        let
          hostFunction = cmd: /*bash*/ ''

          host-rebuild-${cmd}() {
            if [ -z "$1" ]; then
              echo "Usage: host-rebuild-${cmd} <hostname>"
              return 1
            fi

            hostname=$1
            if [[ "$hostname" == "${hostname}" ]]; then
              echo "Error: Cannot build remotely on local host"
              return 1
            fi

            hosts=(${lib.concatStringsSep " " (builtins.attrNames (utils.hosts outputs))})
            if ! (($hosts[(I)$hostname])); then
              echo "Error: Host '$hostname' does not exist" >&2
              return 1
            fi

            ssh-add-quiet
            remote_builds="/home/${username}/files/remote-builds/$hostname"
            mkdir -p "$remote_builds"
            # Build and store result persistently to prevent GC deleting builds
            # for remote hosts
            pushd "$remote_builds" >/dev/null
            nixos-rebuild build --flake "${configDir}#$hostname"
            popd >/dev/null
            if [[ $? -ne 0 ]]; then
              return 1
            fi
            if [[ "$cmd" == "build" ]]; then return 0; fi
            nixos-rebuild ${cmd} --flake "${configDir}#$hostname" --target-host "root@$hostname.lan" "''${@:2}"
          }

        '';
        in
          /*bash*/ ''

          # Hacky script for viewing configuartion diff on remote hosts whilst
          # building locally
          host-rebuild-diff() {
            if [ -z "$1" ]; then
              echo "Usage: host-rebuild-diff <hostname>"
              return 1
            fi

            hostname=$1
            if [[ "$hostname" == "${hostname}" ]]; then
              echo "Error: Cannot diff remotely on local host"
              return 1
            fi

            hosts=(${lib.concatStringsSep " " (builtins.attrNames (utils.hosts outputs))})
            if ! (($hosts[(I)$hostname])); then
              echo "Error: Host '$hostname' does not exist" >&2
              return 1
            fi

            # Because nixos-rebuild doesn't create a 'result' symlink when
            # executed with --build-host we first run host-rebuild-dry-active
            # to ensure that a cached build is on the host so it won't end up
            # trying to build everything itself
            host-rebuild-dry-activate $hostname

            # WARN: The commented out code is an old method that I made under
            # the assumption that store symlinks would be invalid between hosts.
            # If you run into any problems switch to old method

            # Package current config and send to remote host
            # tar -cf /tmp/nixos-diff-config.tar -C ${configDir} .
            # ssh "${username}@$hostname.lan" "rm -rf /tmp/nixos-diff-config; mkdir /tmp/nixos-diff-config"
            # scp /tmp/nixos-diff-config.tar "${username}@$hostname.lan:/tmp/nixos-diff-config"

            # Package build symlink and send to remote host
            tar -cf /tmp/nixos-diff-result.tar -C "/home/${username}/files/remote-builds/$hostname" result
            scp /tmp/nixos-diff-result.tar "${username}@$hostname.lan:/tmp"

            # Build new configuration on remote host using nixos-rebuild build.
            # Compare result with the current system and print the diff.
            # ssh -A "${username}@$hostname.lan" "sh -c \
            #   'cd /tmp/nixos-diff-config && tar -xf nixos-diff-config.tar \
            #   && nixos-rebuild build --flake /tmp/nixos-diff-config#$hostname \
            #   && nvd --color always diff /run/current-system /tmp/nixos-diff-config/result; \
            #   rm -rf /tmp/nixos-diff-config'"

            # Diff the received result with the current system closure
            ssh -A "${username}@$hostname.lan" "tar -xf /tmp/nixos-diff-result.tar -C /tmp && \
              nvd --color always diff \
              /run/current-system /tmp/result; \
              rm -f /tmp/nixos-diff-result.tar; rm -f /tmp/result"
          }

          ${concatStrings (map (cmd: hostFunction cmd) [ "switch" "test" "boot" "dry-activate" "build" ])}

        '';
    };
}
