{
  lib,
  pkgs,
  self,
  config,
  inputs,
  selfPkgs,
  hostname,
  adminUsername,
  ...
}@args:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    mapAttrs
    filterAttrs
    isType
    optional
    mapAttrsToList
    sort
    optionalString
    replaceStrings
    listToAttrs
    nameValuePair
    getExe
    mkForce
    singleton
    concatStringsSep
    toUpper
    ;
  inherit (lib.${ns}) flakePkgs sshAddQuiet upperFirstChar;
  inherit (config.${ns}.system) impermanence;
  inherit (config.age.secrets) notifVars;
  cfg = config.${ns}.core;
  configDir = "/home/${adminUsername}/.config/nixos";

  rebuildCmds = [
    "switch"
    "test"
    "boot"
    "build"
    "dry-build"
    "dry-activate"
    "diff"
  ];

  rebuildScripts = map (
    cmd:
    pkgs.writeShellApplication {
      name = "rebuild-${cmd}";
      runtimeInputs = [ pkgs.nixos-rebuild ] ++ optional (cmd == "diff") pkgs.nvd;
      # Always rebuild in ~ because I once had a bad experience where I
      # accidentally built in /nix/store and caused irrepairable corruption

      # Use --fast on all switch modes apart from boot as I usually do a
      # rebuild-boot after a large nixpkgs change which is the only time when
      # --fast would be bad to use
      text = # bash
        ''
          flake="${configDir}"
          if [ ! -d $flake ]; then
            echo "Flake does not exist locally so using remote from github"
            flake="github:JManch/nixos"
          fi
          trap "popd >/dev/null 2>&1 || true" EXIT
          pushd ~ >/dev/null 2>&1

          nixos-rebuild ${if (cmd == "diff") then "build" else cmd} \
            --use-remote-sudo --flake "$flake#${hostname}" ${optionalString (cmd != "boot") "--fast"} "$@"
          ${optionalString (cmd == "diff") "nvd diff /run/current-system result"}
        '';
    }
  ) rebuildCmds;

  droidRebuildScripts =
    map
      (
        cmd:
        pkgs.writeShellApplication {
          name = "droid-rebuild-${cmd}";
          runtimeInputs = [
            pkgs.nix
            pkgs.openssh
            (flakePkgs args "nix-on-droid").nix-on-droid
          ];
          text = # bash
            ''
              if [ "$#" = 0 ]; then
                echo "Usage: droid-rebuild-${cmd} <hostname>"
                exit 1
              fi
              hostname=$1

              droid_hosts=(${concatStringsSep " " (builtins.attrNames self.nixOnDroidConfigurations)})
              for host in "''${droid_hosts[@]}"; do
                if [[ $host = "$hostname" ]]; then
                  match=1
                  break
                fi
              done

              if [[ $match = 0 ]]; then
                echo "Error: Droid host '$hostname' does not exist" >&2
                exit 1
              fi

              flake="${configDir}"
              if [ ! -d $flake ]; then
                echo "Flake does not exist locally so using remote from github"
                flake="github:JManch/nixos"
              fi

              remote_builds="/home/${adminUsername}/.remote-builds/$hostname"
              mkdir -p "$remote_builds"
              trap "popd >/dev/null 2>&1 || true" EXIT
              pushd "$remote_builds" >/dev/null 2>&1
              nix-on-droid build --flake "$flake#$hostname"
              store_path="$(readlink "/home/${adminUsername}/.remote-builds/$hostname/result")"
              ${
                if (cmd == "switch") then # bash
                  ''
                    NIX_SSHOPTS="-o Port=8022" nix copy --to "ssh://nix-on-droid@$hostname.lan" "$store_path"
                    ssh -p 8022 "nix-on-droid@$hostname.lan" "$store_path/activate"
                  ''
                else
                  "echo \"$store_path\""
              }
            '';
        }
      )
      [
        "build"
        "switch"
      ];

  remoteRebuildScripts = map (
    cmd:
    let
      validation = # bash
        ''
          if [ "$#" = 0 ]; then
            echo "Usage: host-rebuild-${cmd} <hostname>"
            exit 1
          fi

          hostname=$1
          if [[ "$hostname" == "${hostname}" ]]; then
            echo "Error: Cannot ${cmd} remotely on local host"
            exit 1
          fi

          hosts=(${concatStringsSep " " (builtins.attrNames self.nixosConfigurations)})
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

          flake="${configDir}"
          if [ ! -d $flake ]; then
            echo "Flake does not exist locally so using remote from github"
            flake="github:JManch/nixos"
          fi

          # Always build and store result to prevent GC deleting builds for remote hosts
          remote_builds="/home/${adminUsername}/.remote-builds/$hostname"
          mkdir -p "$remote_builds"
          trap "popd >/dev/null 2>&1 || true" EXIT
          pushd "$remote_builds" >/dev/null 2>&1
          nixos-rebuild build --flake "$flake#$hostname" ${optionalString (cmd != "boot") "--fast"} "''${@:2}"
        '';
    in
    pkgs.writeShellApplication {
      name = "host-rebuild-${cmd}";
      runtimeInputs = with pkgs; [
        nixos-rebuild
        openssh
        nvd
      ];
      text =
        validation
        + (
          if (cmd == "diff") then # bash
            ''
              if [ ! -d "${configDir}" ]; then
                echo "rebuild-diff requires the flake to exist locally in ${configDir}"
                exit 1
              fi

              remote_system=$(ssh "${adminUsername}@$hostname.lan" readlink /run/current-system)
              nixos_system=$(readlink "$remote_builds/result")
              nix-copy-closure --from "$hostname.lan" "$remote_system"
              nvd --color always diff "$remote_system" "$nixos_system"
            ''
          else
            optionalString (cmd != "build") # bash
              ''
                ${sshAddQuiet args}
                nixos-rebuild ${cmd} ${optionalString (cmd != "boot") "--fast"} \
                  --use-remote-sudo --flake "$flake#$hostname" --target-host "root@$hostname.lan" "''${@:2}"
              ''
        );
    }
  ) rebuildCmds;

  flakeUpdate = singleton (
    pkgs.writeShellApplication {
      name = "flake-update";
      runtimeInputs = [ pkgs.jaq ];
      text = # bash
        ''
          # List of critical inputs to check for revision changes
          critical_inputs=(
            "impermanence"
            "home-manager"
            "agenix"
            "lanzaboote"
            "disko"
            "vpn-confinement"
            "raspberry-pi-nix"
            "rpi-firmware-nonfree-src"
            "nixpkgs-xr"
            "nix-on-droid"
            "nix-flatpak"
          )

          # Inputs and with relative file paths to check for changes in.
          # Separate multiple file paths with spaces.
          declare -A input_file_pairs=(
            ["nixpkgs"]="nixos/modules/tasks/filesystems/zfs.nix nixos/modules/programs/wayland/hyprland.nix nixos/modules/programs/wayland/uwsm.nix nixos/modules/services/desktops/flatpak.nix"
          )

          input_exists_in_lockfiles() {
            local input="$1"
            local old_lock="$2"
            local new_lock="$3"
            if echo "$old_lock" | jaq -e ".\"$input\"" &>/dev/null &&
               echo "$new_lock" | jaq -e ".\"$input\"" &>/dev/null; then
              return 0
            else
              return 1
            fi
          }

          old_lock=$(<"${configDir}/flake.lock" jaq -c '.nodes')
          pushd "${configDir}" >/dev/null
          nix flake update
          popd >/dev/null
          new_lock=$(<"${configDir}/flake.lock" jaq -c '.nodes')

          first_diff=true
          for input in "''${critical_inputs[@]}"; do
            if input_exists_in_lockfiles "$input" "$old_lock" "$new_lock"; then
              old_rev=$(echo "$old_lock" | jaq -r ".\"$input\".locked.rev")
              new_rev=$(echo "$new_lock" | jaq -r ".\"$input\".locked.rev")

              if [ "$new_rev" != "$old_rev" ]; then
                if $first_diff; then
                  echo -e "\033[1;31m\nCritical inputs have updated. Check changes using the URLs below:\n\033[0m"
                  first_diff=false
                fi
                echo -e "\033[1m• Updated critical input '$input':\033[0m"
                source_type=$(echo "$new_lock" | jaq -r ".\"$input\".original.type")
                if [[ "$source_type" == "github" || "$source_type" == "gitlab" ]]; then
                  owner=$(echo "$new_lock" | jaq -r ".\"$input\".original.owner")
                  repo=$(echo "$new_lock" | jaq -r ".\"$input\".original.repo")
                  echo "    'https://$source_type.com/$owner/$repo/compare/$old_rev...$new_rev'"
                else
                  echo -e "\033[1;31m   Cannot get diff URL, source type $source_type is unsupported\033[0m"
                fi
              fi
            fi
          done

          tmp_repos=$(mktemp -d)
          cleanup() {
            rm -rf "$tmp_repos"
          }
          trap cleanup EXIT
          first_diff=true

          for input in "''${!input_file_pairs[@]}"; do
            file_paths="''${input_file_pairs[$input]}"
            IFS=' ' read -r -a paths_array <<< "$file_paths"
            for file_path in "''${paths_array[@]}"; do
              if input_exists_in_lockfiles "$input" "$old_lock" "$new_lock"; then
                old_rev=$(echo "$old_lock" | jaq -r ".\"$input\".locked.rev")
                new_rev=$(echo "$new_lock" | jaq -r ".\"$input\".locked.rev")

                source_type=$(echo "$new_lock" | jaq -r ".\"$input\".original.type")
                if [ "$new_rev" != "$old_rev" ]; then
                  if [[ "$source_type" == "github" || "$source_type" == "gitlab" ]]; then
                    owner=$(echo "$new_lock" | jaq -r ".\"$input\".original.owner")
                    repo=$(echo "$new_lock" | jaq -r ".\"$input\".original.repo")
                    ref=$(echo "$new_lock" | jaq -r ".\"$input\".original.ref")
                    repo_dir="$tmp_repos/$input"

                    if [ -d "/home/${adminUsername}/files/repos/$repo/.git" ]; then
                      repo_dir="/home/${adminUsername}/files/repos/$repo"
                    elif [ ! -d "$tmp_repos/$input" ]; then
                      git clone "https://$source_type.com/$owner/$repo" "$tmp_repos/$input" -q
                    fi

                    pushd "$repo_dir" >/dev/null

                    # In our local nixpkgs repo origin is our fork
                    if [[ "$repo" == "nixpkgs" && "$repo_dir" != "$tmp_repos/$input" && "$owner" == "NixOS" ]]; then
                      git fetch upstream "$ref" -q
                    else
                      git fetch origin "$ref" -q
                    fi

                    diff_output=$(git diff "$old_rev" "$new_rev" -- "$file_path")
                    if [[ -n "$diff_output" ]]; then
                      if $first_diff; then
                        echo -e "\033[1;34m\nTracked input files have changed. View diffs below:\n\033[0m"
                        first_diff=false
                      fi
                      echo -e "\033[1m• File changed for input '$input': $file_path\033[0m"
                      diff_output_path=$(mktemp -p /tmp "$input-diff-XXXXX")
                      echo "$diff_output" > "$diff_output_path"
                      echo "    '$diff_output_path'"
                    fi
                    popd >/dev/null
                  else
                    echo -e "\033[1;31m• Cannot check file paths diff for input '$input', source type '$source_type' is unsupported\033[0m"
                  fi
                fi
              fi
            done
          done
        '';
    }
  );
in
{
  adminPackages =
    [ pkgs.nvd ] ++ rebuildScripts ++ remoteRebuildScripts ++ droidRebuildScripts ++ flakeUpdate;
  persistenceAdminHome.directories = [ ".remote-builds" ];
  boot.binfmt.emulatedSystems = cfg.builder.emulatedSystems;
  services.getty.helpLine = mkForce "";

  # Useful for finding the exact config that built a generation
  environment.etc.current-flake.source = ../../..;

  # Include flake git rev in system label
  system.nixos.label = concatStringsSep "-" (
    (sort (x: y: x < y) config.system.nixos.tags)
    ++ [ "${config.system.nixos.version}-${self.sourceInfo.shortRev or "dirty"}" ]
  );

  # Nice explanation of overlays: https://archive.is/f8goR
  # How to override python packages:
  # https://nixos.org/manual/nixpkgs/unstable/#how-to-override-a-python-package-using-overlays
  nixpkgs = {
    overlays = [
      (final: prev: {
        inherit (selfPkgs) xdg-terminal-exec;
      })
    ];
    config.allowUnfree = true;
  };

  nix =
    let
      flakeInputs = filterAttrs (_: isType "flake") inputs;
    in
    {
      channel.enable = false;
      daemonIOSchedClass = mkIf (!cfg.builder.enable) "idle";
      daemonCPUSchedPolicy = mkIf (!cfg.builder.enable) "idle";

      # Populates the nix registry with all our flake inputs `nix registry list`
      # Enables referencing flakes with short name in nix commands
      # e.g. 'nix shell n#dnsutils' or 'nix shell hyprland#wlroots-hyprland'
      registry = (mapAttrs (_: flake: { inherit flake; }) flakeInputs) // {
        self.flake = self;
        n.flake = inputs.nixpkgs;
      };

      # Add flake inputs to nix path. Enables loading flakes with <flake_name>
      # like how <nixpkgs> can be referenced.
      nixPath = mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      settings = {
        experimental-features = [
          "flakes"
          "nix-command"
          "auto-allocate-uids"
        ];
        allow-import-from-derivation = false;
        auto-optimise-store = true;
        # Do not create a bunch of nixbld users
        auto-allocate-uids = true;
        # Do not load the default global registry
        # https://channels.nixos.org/flake-registry.json
        flake-registry = "";
        # WARN: Do not use this, it's insecure
        # https://github.com/NixOS/nix/issues/9649#issuecomment-1868001568
        # trusted-users = [ adminUsername ];
        substituters = [
          "https://nix-community.cachix.org"
          "https://nix-on-droid.cachix.org"
          "https://ghostty.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU="
          "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
        ];
        build-dir = mkIf impermanence.enable "/var/nix-tmp";
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
    dates = "weekly";
    randomizedDelaySec = "2hours";
  };

  systemd.services = mkIf cfg.autoUpgrade (mkMerge [
    (listToAttrs (
      map
        (
          type:
          nameValuePair "nixos-upgrade-${type}" {
            restartIfChanged = false;
            serviceConfig = {
              type = "oneshot";
              EnvironmentFile = notifVars.path;
              ExecStart =
                let
                  title = "NixOS Auto Upgrade ${upperFirstChar type}";
                  message = "Auto upgrade ${if type == "success" then "succeeded" else type} on host ${hostname}";
                  shoutrrr = getExe pkgs.shoutrrr;
                in
                pkgs.writeShellScript "nixos-upgrade-${type}-notif" (
                  ''
                    ${shoutrrr} send \
                      --url "discord://$UPGRADE_DISCORD_AUTH_${toUpper type}" \
                      --title "${title}" \
                      --message "${message}"
                  ''
                  + optionalString (type == "failure") ''
                    ${shoutrrr} send \
                      --url "smtp://$SMTP_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=${
                        replaceStrings [ " " ] [ "%20" ] title
                      }" \
                      --message "${message}"
                  ''
                );
            };
          }
        )
        [
          "success"
          "failure"
        ]
    ))
    {
      nixos-upgrade = {
        onFailure = [ "nixos-upgrade-failure.service" ];
        onSuccess = [ "nixos-upgrade-success.service" ];
        # Because one of our flake inputs is a private repo temporarily copy host ssh
        # keys so root uses them to authenticate with github
        serviceConfig.ExecStart = mkForce (pkgs.writeShellScript "nixos-upgrade-ssh-auth" ''
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
      };
    }
  ]);

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
  systemd.tmpfiles.rules = mkIf impermanence.enable [
    "d /var/nix-tmp 0755 root root - -"
    "d /persist/var/nix-tmp 0755 root root - -"
  ];

  programs.command-not-found.enable = false;
  programs.nix-index = {
    # Nix-index doesn't work with cross compilation
    enable = with pkgs; hostPlatform == buildPlatform;
    package = (flakePkgs args "nix-index-database").nix-index-with-db;
  };

  programs.zsh = {
    interactiveShellInit = # bash
      ''
        inspect-host() {
          if [ -z "$1" ]; then
            echo "Usage: inspect-host <hostname>"
            return 1
          fi
          nixos-rebuild repl --flake "${configDir}#$1"
        }

        build-package() {
          NIXPKGS_ALLOW_UNFREE=1 nix build --impure --expr "with import <nixpkgs> {}; pkgs.callPackage $1 {}"
        }
      '';

    shellAliases = {
      mount-nix-tmp = mkIf impermanence.enable "sudo mount --bind /persist/var/nix-tmp /var/nix-tmp";
      system-size = "nix path-info --closure-size --human-readable /run/current-system";
    };
  };
}
