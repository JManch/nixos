{ lib
, pkgs
, self
, config
, inputs
, username
, hostname
, ...
}:
let
  inherit (lib)
    mkIf
    utils
    mapAttrs
    filterAttrs
    isType
    mapAttrsToList
    optionalString
    mkForce
    concatStringsSep
    getExe;
  inherit (config.modules.system) impermanence;
  cfg = config.modules.core;
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

  rebuildScripts = map
    (cmd: pkgs.writeShellApplication {
      name = "rebuild-${cmd}";
      runtimeInputs = with pkgs; [ nixos-rebuild ];
      # Always rebuild in ~ because I once had a bad experience where I
      # accidentally built in /nix/store and caused irrepairable corruption
      text = /*bash*/ ''
        ${cfg.loadNixResourcesKey}
        add_exit_trap "popd >/dev/null 2>&1 || true"
        pushd ~ >/dev/null 2>&1

        nixos-rebuild ${if (cmd == "diff") then "build" else cmd} \
          --use-remote-sudo --flake "$flake#${hostname}" "$@"
        ${optionalString (cmd == "diff") /*bash*/ ''
          nvd diff /run/current-system result
        ''}
      '';
    })
    rebuildCmds;

  remoteRebuildScripts = map
    (cmd:
      let
        validation = /*bash*/ ''
          if [ "$#" = 0 ]; then
            echo "Usage: host-rebuild-${cmd} <hostname>"
            exit 1
          fi

          hostname=$1
          if [[ "$hostname" == "${hostname}" ]]; then
            echo "Error: Cannot ${cmd} remotely on local host"
            exit 1
          fi

          hosts=(${concatStringsSep " " (builtins.attrNames (utils.hosts self))})
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

          ${cfg.loadNixResourcesKey}
        '';
      in
      pkgs.writeShellApplication {
        name = "host-rebuild-${cmd}";
        runtimeInputs = with pkgs; [ nixos-rebuild openssh ];
        text = validation + (if (cmd == "diff") then /*bash*/ ''
          if [ ! -d "${configDir}" ]; then
            echo "rebuild-diff requires the flake to exist locally in ${configDir}"
            exit 1
          fi

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
          add_exit_trap "popd >/dev/null 2>&1 || true"
          pushd "$remote_builds" >/dev/null 2>&1
          nixos-rebuild build --flake "$flake#$hostname" "''${@:2}"
          ${optionalString (cmd != "build") /*bash*/ ''
            nixos-rebuild ${cmd} --use-remote-sudo --flake "$flake#$hostname" --target-host "root@$hostname.lan" "''${@:2}"
          ''}

        '');
      })
    rebuildCmds;
in
{
  environment.systemPackages = [ pkgs.nvd ] ++ rebuildScripts ++ remoteRebuildScripts;

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

  system.autoUpgrade = mkIf cfg.autoUpgrade {
    enable = true;
    flake = "github:JManch/nixos";
    operation = "boot";
    dates = "daily";
  };

  # Because one of our flake inputs is a private repo temporarily copy host ssh
  # keys so root uses them to authenticate with github
  systemd.services.nixos-upgrade.serviceConfig.ExecStart = mkForce (pkgs.writeShellScript "nixos-upgrade-ssh-auth" ''
    # Copy host ssh keys to /root/.ssh
    # Abort if /root.ssh exists
    if [ -d /root/.ssh ]; then
      echo "Aborting because root has ssh keys for some reason"
      exit 1
    fi
    mkdir -p /root/.ssh
    cp /etc/ssh/ssh_host_ed25519_key /root/.ssh/id_ed25519
    ${config.systemd.services.nixos-upgrade.script}
    rm -rf /root/.ssh
  '').outPath;

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
  systemd.services.nix-daemon.environment.TMPDIR = mkIf impermanence.enable "/var/nix-tmp";
  systemd.tmpfiles.rules = mkIf impermanence.enable [
    "d /var/nix-tmp 0755 root root"
    "d /persist/var/nix-tmp 0755 root root"
  ];

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
      mount-nix-tmp = mkIf impermanence.enable "sudo mount --bind /persist/var/nix-tmp /var/nix-tmp";
      build-iso = "nix build ${configDir}#nixosConfigurations.installer.config.system.build.isoImage";
    };
  };
}
