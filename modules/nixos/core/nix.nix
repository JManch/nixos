{ lib
, pkgs
, config
, inputs
, outputs
, username
, hostname
, ...
}:
let
  inherit (lib)
    utils
    mapAttrs
    filterAttrs
    isType
    mapAttrsToList
    optionalString
    concatStringsSep
    concatMap
    all
    attrNames
    hasAttr;
  configDir = "/home/${username}/.config/nixos";

  rebuildCmds = [
    "switch"
    "test"
    "boot"
    "build"
    "dry-build"
    "dry-activate"
    "diff"
  ];

  rebuildScript = cmd: pkgs.writeShellApplication {
    name = "rebuild-${cmd}";
    runtimeInputs = with pkgs; [ nixos-rebuild nvd ];
    # Always rebuild in ~ because I once had a bad experience where I
    # accidentally built in /nix/store and caused irrepairable corruption
    text = /*bash*/ ''
      pushd ~ >/dev/null 2>&1 
      exit() {
        popd >/dev/null 2>&1
      }
      trap exit EXIT
      nixos-rebuild ${cmd} --use-remote-sudo --flake "${configDir}#${hostname}" "$@"
      ${optionalString (cmd == "diff") /*bash*/ ''
        nvd diff /run/current-system result
      ''}
    '';
  };

  remoteRebuildScript = cmd:
    let
      validation = /*bash*/ ''
        if [ "$#" -ne 1 ]; then
          echo "Usage: host-rebuild-${cmd} <hostname>"
          exit 1
        fi

        hostname=$1
        if [[ "$hostname" == "${hostname}" ]]; then
          echo "Error: Cannot ${cmd} remotely on local host"
          exit 1
        fi

        hosts=(${concatStringsSep " " (builtins.attrNames (utils.hosts outputs))})
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
      '';
    in
    pkgs.writeShellApplication {
      name = "host-rebuild-${cmd}";
      runtimeInputs = with pkgs; [ nixos-rebuild openssh ];
      text = validation + (if (cmd == "diff") then /*bash*/ ''

        # Because nixos-rebuild doesn't create a 'result' symlink when
        # executed with --build-host we first run build locally with
        # --target-host to ensure that a cached build is on the host and it
        # won't end up trying to build everything itself
        nixos-rebuild build --flake "${configDir}#$hostname" --target-host "root@$hostname.lan"

        # For some reason running nixos-rebuild build --target-host sends a
        # system with a different root system hash to the one built locally.
        # Therefore we have to generate the "result" symlink on the remote host
        # by building locally. Downside is the remote host has to run nix
        # evaluation itself.

        # Package current config and send to remote host
        tar -cf /tmp/nixos-diff-config.tar -C ${configDir} .
        ssh "${username}@$hostname.lan" "rm -rf /tmp/nixos-diff-config; mkdir /tmp/nixos-diff-config"
        scp /tmp/nixos-diff-config.tar "${username}@$hostname.lan:/tmp/nixos-diff-config"

        # Build new configuration on remote host and generate result
        # symlink. Diff the result with the current system
        # shellcheck disable=SC2029
        ssh "${username}@$hostname.lan" "sh -c \
          'cd /tmp/nixos-diff-config && \
          tar -xf nixos-diff-config.tar && \
          nixos-rebuild build --flake .#$hostname && \
          nvd --color always diff /run/current-system ./result; \
          rm -rf /tmp/nixos-diff-config'"

      '' else /*bash*/ ''

        # Always build and store result to prevent GC deleting builds for remote hosts
        remote_builds="/home/${username}/files/remote-builds/$hostname"
        mkdir -p "$remote_builds"
        pushd "$remote_builds" >/dev/null 2>&1
        exit() {
          popd >/dev/null 2>&1
        }
        trap exit EXIT
        nixos-rebuild build --flake "${configDir}#$hostname" "''${@:2}"
        ${optionalString (cmd != "build") /*bash*/ ''
          nixos-rebuild ${cmd} --use-remote-sudo --flake "${configDir}#$hostname" --target-host "root@$hostname.lan" "''${@:2}"
        ''}

      '');
    };

  deployScript = pkgs.writeShellApplication {
    name = "deploy-host";
    runtimeInputs = [
      pkgs.age
      # nixos-anywhere does not allow passing extra flags to the nix build commands
      # so we have to patch it. The patch overrides our 'firstBoot' flake input to
      # 'true' so that we can change certain config options for the very first
      # build of a system. This is useful for options like secure boot that need
      # extra configuration to work.
      # This patch also preserves the file ownership in the rsync command used
      # for extra-files transfer. This is needed for deploying secrets to the
      # home directory.
      (utils.addPatches pkgs.nixos-anywhere [ ../../../patches/nixosAnywhere.patch ])
      pkgs.gnutar
    ];
    text = /*bash*/ ''
      if [ "$#" -ne 2 ]; then
        echo "Usage: deploy-host <hostname> <ip_address>"
        exit 1
      fi

      # Exclude hosts that use zfs disk encryption because nixos-anywhere will
      # get stuck when setting disk passphrase
      hosts=(${
        concatStringsSep " " (
          attrNames (
            filterAttrs (
              _: value:
              all (v: v == false) (
                mapAttrsToList (_: pool: hasAttr "encryption" pool.rootFsOptions) value.config.disko.devices.zpool
              )
            ) (utils.hosts outputs)
          )
        )
      })

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
        echo "Error: Host '$hostname' either does not exist or uses disk encryption" >&2
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
  environment.systemPackages = [
    deployScript
  ] ++ (concatMap (cmd: [ (rebuildScript cmd) (remoteRebuildScript cmd) ]) rebuildCmds);

  # Nice explanation of overlays: https://archive.is/f8goR
  #
  # My summary of the differences between overlays and `overrideAttrs`:
  #
  # Overlays modify the package derivation in nixpkgs whilst `overrideAttrs`
  # only modifies the package in the current context. In practice this means
  # that modifications made with overlays will apply to all instances of the
  # package throughout your entire configuration. If you want to modify a core
  # package that many modules and packages depend on, you can see how this is a
  # powerful feature. However, if not used carefully, overlays can trigger an
  # unwanted system-wide butterfly effect on package dependencies causing many
  # packages to be rebuilt from source. This is because modifying a package in
  # nixpkgs will result in all packages that depend on this package to have
  # their derivation modified and therefore their cache invalidated.
  #
  # `overrideAttrs` avoids this problem because the package is ONLY modified in
  # the context where you applied the override. This means that any dependent
  # packages will continue to use the unmodified version and will continue to
  # use the binary cache. If a module has a `package` option, this can be a
  # convenient place to apply the override as the package will be stored in the
  # option and can be easily reused elsewhere.
  #
  # In my experience, for the majority of packages that I'm overriding, only
  # overriding the package in the current context is sufficient. It has the
  # advantage of being more explicit than overlays and also guarantees no
  # unexpected dependency butterfly effects.
  #
  # Overlays allow for greater modifications to packages than `overrideAttrs`.
  # Literally anything is possible. The entire derivation can be replaced with
  # an entirely different package if desired. However, once again, in the vast
  # majority of cases this extra functionality is not required.
  #
  # To summarise, for the majority of situations where you want to modify a
  # package (using a different src, applying a patch etc...) overlays are NOT
  # necessary and `overrideAttrs` can be used instead. However depending on the
  # situation, overlays might be more convenient or required for their extra
  # functionality.
  nixpkgs = {
    overlays = [ ];
    config.allowUnfree = true;
  };

  nix =
    let
      flakeInputs = filterAttrs (_: isType "flake") inputs;
    in
    {
      channel.enable = false;

      # Populates the nix registry with all our flake inputs `nix registry list`
      # Enables referencing flakes with short name in nix commands 
      # e.g. 'nix shell n#dnsutils' or 'nix shell hyprland#wlroots-hyprland'
      registry = (mapAttrs (_: flake: { inherit flake; }) flakeInputs) // {
        self.flake = inputs.self;
        n.flake = inputs.nixpkgs;
      };

      # Add flake inputs to nix path. Enables loading flakes with <flake_name>
      # like how <nixpkgs> can be referenced.
      nixPath = mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      settings = {
        experimental-features = "nix-command flakes";
        auto-optimise-store = true;
        # Do not load the default global registry
        # https://channels.nixos.org/flake-registry.json
        flake-registry = "";
        # Fixes builds using --build-host
        trusted-users = [ username ];
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };

  # Sometimes nixos-rebuild compiles large pieces software that require more
  # space in /tmp than my tmpfs can provide. The obvious solution is to mount
  # /tmp to some actual storage. However, the majority of my rebuilds do not
  # need the extra space and I'd like to avoid the extra disk wear. By using a
  # custom tmp directory for nix builds, I can bind mount the build dir to
  # persistent storage when I know the build will be large. This wouldn't be
  # possible with the standard /tmp dir because bind mounting /tmp on a running
  # system would break things.
  # Relevant github issue: https://github.com/NixOS/nixpkgs/issues/54707

  # List of programs that require the bind mount to compile:
  # - mongodb
  systemd = {
    services.nix-daemon.environment.TMPDIR = "/var/nix-tmp";
    tmpfiles.rules = [
      "d /var/nix-tmp 0755 root root"
      "d /persist/var/nix-tmp 0755 root root"
    ];
  };

  programs.zsh = {
    interactiveShellInit = /*bash*/ ''
      inspect-host() {
        if [ -z "$1" ]; then
          echo "Usage: inspect-host <hostname>"
          return 1
        fi
        nixos-rebuild repl --flake "${configDir}#$1"
      }
    '';

    shellAliases = {
      mount-nix-tmp = "sudo mount --bind /persist/var/nix-tmp /var/nix-tmp";
      build-iso = "nix build ${configDir}#nixosConfigurations.installer.config.system.build.isoImage";
    };
  };
}
