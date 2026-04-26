{
  lib,
  cfg,
  pkgs,
  self,
  args,
  config,
  inputs,
  sources,
  hostname,
  username,
  adminUsername,
}:
let
  inherit (lib)
    ns
    mkIf
    mapAttrs
    filterAttrs
    types
    isType
    optional
    assertMsg
    optionals
    mapAttrsToList
    sort
    optionalString
    concatMap
    attrNames
    boolToString
    attrValues
    mkForce
    singleton
    concatStringsSep
    mkEnableOption
    mkOption
    ;
  inherit (lib.${ns})
    addPatches
    flakePkgs
    hostIps
    hostVPNIp
    ;
  inherit (inputs.nix-resources.secrets) keys;
  inherit (config.${ns}.system) impermanence;
  inherit (config.${ns}.core) home-manager device;
  configDir = "/home/${adminUsername}/.config/nixos";

  rebuildCmds = [
    "switch"
    "test"
    "boot"
    "build"
    "diff"
  ];

  rebuildScripts = map (
    cmd:
    pkgs.writeShellApplication {
      name = "rebuild-${cmd}";
      runtimeInputs = [ pkgs.nh ];
      text = ''
        flake="${configDir}"
        if [[ ! -d $flake ]]; then
          echo "Flake does not exist locally so using remote from github"
          flake="github:JManch/nixos"
        fi

        nh os ${
          if (cmd == "diff") then "build" else cmd
        } "$flake" --hostname ${hostname} --out-link ~/result-${hostname} --diff always ${
          optionalString (cmd != "diff" && cmd != "build") "--show-activation-logs "
        }"$@"
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
          text = ''
            if [ "$#" = 0 ]; then
              echo "Usage: droid-rebuild-${cmd} <hostname>"
              exit 1
            fi
            hostname=$1

            droid_hosts=(${concatStringsSep " " (attrNames self.nixOnDroidConfigurations)})
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

            remote_builds="/home/${adminUsername}/.remote-builds"
            mkdir -p "$remote_builds"
            trap "popd >/dev/null 2>&1 || true" EXIT
            tmp=$(mktemp -d)
            pushd "$tmp" >/dev/null 2>&1
            nix-on-droid build --flake "$flake#$hostname"
            mv "$tmp/result" "$remote_builds/result-$hostname"
            store_path="$(readlink "$remote_builds/result-$hostname")"
            ${
              if (cmd == "switch") then
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

          hosts=(${concatStringsSep " " (attrNames self.nixosConfigurations)})
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
          remote_builds="/home/${adminUsername}/.remote-builds"
          mkdir -p "$remote_builds"

          # Check if host is on VPN
          ${optionalString (cmd != "build")
            # bash
            ''
              if ping -c 1 -W 1 "$hostname.lan" >/dev/null; then
                host_address="$hostname.lan"
              elif ping -c 1 -W 1 "$hostname-vpn.lan" >/dev/null; then
                host_address="$hostname-vpn.lan"
              else
                echo "Host '$hostname' is not up"
              fi
            ''
          }
        '';
    in
    pkgs.writeShellApplication {
      name = "host-rebuild-${cmd}";
      runtimeInputs = [
        pkgs.nh
      ]
      ++ optionals (cmd == "diff") [
        pkgs.nix
        pkgs.openssh
        pkgs.dix
      ];
      text =
        validation
        + (
          if (cmd == "build" || cmd == "diff") then
            ''
              nh os build "$flake" --hostname "$hostname" --out-link "$remote_builds/result-$hostname" "''${@:2}"
              ${optionalString (cmd == "diff") ''
                remote_system=$(ssh "${adminUsername}@$host_address" readlink /run/current-system)
                built_system=$(readlink "$remote_builds/result-$hostname")
                nix copy --from "ssh://$host_address" "$remote_system"
                dix "$remote_system" "$built_system"
              ''}
            ''
          else
            ''
              nh os ${cmd} "$flake" --elevation-program=none --hostname "$hostname" --out-link "$remote_builds/result-$hostname" --target-host "root@$host_address" "''${@:2}"
            ''
        );
    }
  ) rebuildCmds;

  flakeUpdate = singleton (
    pkgs.writeShellApplication {
      name = "flake-update";
      runtimeInputs = [ pkgs.jaq ];
      text = ''
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
          "nvf"
        )

        # Inputs and with relative file paths to check for changes in.
        # Separate multiple file paths with spaces.
        declare -A input_file_pairs=(
          ["nixpkgs"]="nixos/modules/tasks/filesystems/zfs.nix nixos/modules/programs/wayland/hyprland.nix nixos/modules/programs/wayland/uwsm.nix nixos/modules/services/desktops/flatpak.nix nixos/modules/services/video/frigate.nix nixos/modules/services/networking/wpa_supplicant.nix"
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
  enableOpt = false;

  opts = {
    autoUpgrade = mkEnableOption "auto upgrade";

    builder = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this host is a high-performance nix builder";
      };

      shareStore = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to share this host's Nix store over SSH. All others hosts will have this host added as a substituter.
        '';
      };

      emulatedSystems = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of systems to support for emulated compilation. Requires a
          reboot to take effect.
        '';
      };
    };
  };

  ns.adminPackages = [
    pkgs.nh
    pkgs.dix
    pkgs.npins
  ]
  ++ rebuildScripts
  ++ remoteRebuildScripts
  ++ droidRebuildScripts
  ++ flakeUpdate;
  ns.persistenceAdminHome.directories = [ ".remote-builds" ];
  boot.binfmt.emulatedSystems = cfg.builder.emulatedSystems;
  services.getty.helpLine = mkForce "";

  # Include flake git rev in system label
  system.nixos.label = concatStringsSep "-" (
    (sort (x: y: x < y) config.system.nixos.tags)
    ++ [ "${config.system.nixos.version}-${self.sourceInfo.shortRev or "dirty"}" ]
  );

  # Useful for finding the exact config that built a generation
  environment.etc = {
    current-flake.source = self;
    current-rev.text = "${self.sourceInfo.rev or "dirty"}";
  };

  # Nice explanation of overlays: https://archive.is/f8goR
  # How to override python packages:
  # https://nixos.org/manual/nixpkgs/unstable/#how-to-override-a-python-package-using-overlays
  # How to override rust cargo deps:
  # overrideAttrs rec {
  #   ...
  #   cargoDeps = final.rustPlatform.fetchCargoVendor {
  #     inherit src;
  #     hash = "";
  #   };
  # }
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      (final: prev: {
        inherit (final.${ns}) brightnessctl;
        microfetch = addPatches prev.microfetch [ "microfetch-icon.patch" ];

        # Uses the emblem-default-symbolic icon which has been removed from the
        # adwaita icon theme
        # https://gitlab.gnome.org/GNOME/gnome-terminal/-/issues/8126
        # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1109086
        pwvucontrol = addPatches prev.pwvucontrol [ "pwvucontrol-icon-fix.patch" ];

        xdg-terminal-exec = prev.xdg-terminal-exec.overrideAttrs {
          inherit (sources.xdg-terminal-exec) version;
          src = sources.xdg-terminal-exec;
        };

        rnnoise-plugin = addPatches prev.rnnoise-plugin (
          optional (
            !final.stdenv.buildPlatform.canExecute final.stdenv.hostPlatform
          ) "rnnoise-plugin-cross.patch"
        );

        # https://github.com/novnc/noVNC/issues/1946
        novnc =
          assert assertMsg (prev.novnc.version == "1.6.0") "novnc patch should be in stable now";
          addPatches prev.novnc [
            (final.fetchpatch2 {
              url = "https://github.com/novnc/noVNC/commit/f0a39cd357a5995673149b95951d4c1261b69571.patch";
              hash = "sha256-GTXFAK1T8LiCIuukYFIOqoXNbrXJF0smTzALBdry9eA=";
            })
          ];

        lact =
          assert assertMsg (prev.lact.version == "0.8.4") "remove lact overlay";
          prev.lact.overrideAttrs (old: rec {
            version = "0.9.0";
            src = final.fetchFromGitHub {
              owner = "ilya-zlobintsev";
              repo = "LACT";
              tag = "v0.9.0";
              hash = "sha256-c5GJf8AYgaAN3O6AVSEbJybEYb6lSHf7R24/1PKYhyM=";
            };
            cargoDeps = final.rustPlatform.fetchCargoVendor {
              inherit src;
              hash = "sha256-Y+XdCmaDXdP7x22bYm//Ov7+IzlCr8GpFOgCXGFCfbA=";
            };
            buildInputs = old.buildInputs ++ [ final.libadwaita ];
          });

        # inherit
        #   (
        #     assert lib.assertMsg (prev.navidrome.version == "0.60.0") "Remove navidrome overlay";
        #     import (fetchTree "github:tebriel/nixpkgs/1a13ff7aaa65cee4271854cfb41f01f006b20864") {
        #       inherit (pkgs.stdenv.hostPlatform) system;
        #     }
        #   )
        #   navidrome
        #   ;
      })
    ];
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

      # https://nix.dev/manual/nix/2.26/package-management/ssh-substituter
      sshServe = mkIf cfg.builder.shareStore {
        enable = true;
        trusted = false;
        protocol = "ssh-ng";
        # The nix-ssh user is only capable of running `nix serve` and ssh substituters
        # do not support passphrase encrypted keys so just use host keys
        keys = [ keys.ssh-host.framework ]; # should really be attrValues keys.ssh-host; but don't need that right now
      };

      settings = {
        experimental-features = [
          "flakes"
          "nix-command"
          "auto-allocate-uids"
        ];
        trace-import-from-derivation = true;
        # Causes excessive writes and potential slow downs when writing
        # content to the nix store. Optimising once a week with
        # `nix.optimise.automatic` is probably better?
        auto-optimise-store = false;
        # Do not create a bunch of nixbld users
        auto-allocate-uids = true;
        # Do not load the default global registry
        # https://channels.nixos.org/flake-registry.json
        flake-registry = "";
        # WARN: Do not use this, it's insecure
        # https://github.com/NixOS/nix/issues/9649#issuecomment-1868001568
        # trusted-users = [ adminUsername ];
        allowed-users = [
          adminUsername
        ]
        ++
          optional (username != adminUsername && home-manager.enable)
            # Home manager user needs access to the nix daemon for some reason
            # https://github.com/nix-community/home-manager/issues/5704
            # https://github.com/nix-community/home-manager/issues/4014
            username
        ++ optional (cfg.builder.enable && cfg.builder.shareStore) "nix-ssh";

        min-free = 128000000; # 128MB
        max-free = 1000000000; # 1GB

        # Default is 300 seconds is not ideal for our ssh-ng substituters which may be offline
        # Also nix crashes... https://github.com/NixOS/nix/issues/3768
        # Per-substituter timeout would be nice https://github.com/NixOS/nix/issues/3768
        connect-timeout = 5;

        # Try to build from source instead of failing when a substituter is
        # down. Basically a necessity for our host binary caches which may be
        # offline. Should also improve offline build experience.
        # (I assume substituter paths are cached so even when offline, nix
        # knows if a substituter has a path?)
        fallback = true;

        substituters = [
          "https://nix-community.cachix.org"
          # "https://nix-on-droid.cachix.org"
        ]
        ++ (
          assert lib.assertMsg (pkgs.lan-mouse.version == "0.10.0") "Remove lan-mouse substituter";
          [ "https://lan-mouse.cachix.org/" ]
        )
        ++ (concatMap (
          host:
          let
            builderConfig = self.nixosConfigurations.${host}.config.${ns}.core.nix.builder;
          in
          optionals (host != hostname && builderConfig.enable && builderConfig.shareStore) (
            # Give this substituter low priority and compress on VPN connections because upload speed will likely be slow
            map (
              ip:
              "ssh-ng://nix-ssh@${ip}?compress=${
                boolToString (ip == hostVPNIp host)
              }&priority=100&ssh-key=/etc/ssh/ssh_host_ed25519_key&base64-ssh-public-host-key=${keys.base64-ssh-host.${host}}"
            ) (hostIps host)
          )
        ) (attrNames self.nixosConfigurations));

        # We need to sign our store contents for reliable `nix copy` usage
        # https://github.com/NixOS/nix/issues/2127
        secret-key-files = mkIf cfg.builder.enable [ "/etc/nix/nix_store_ed25519_key" ];

        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU="
        ]
        ++ attrValues keys.nix-store
        ++ (
          assert lib.assertMsg (pkgs.lan-mouse.version == "0.10.0") "Remove lan-mouse public key";
          [ "lan-mouse.cachix.org-1:KlE2AEZUgkzNKM7BIzMQo8w9yJYqUpor1CAUNRY6OyM=" ]
        );

        build-dir = mkIf impermanence.enable "/var/nix-tmp";
      };

      # https://github.com/NixOS/nix/issues/6536#issuecomment-1254858889
      extraOptions = ''
        !include ${config.age.secrets.nixAccessTokens.path}
      '';

      gc = {
        automatic = true;
        dates = "Mon *-*-* 00:00:00";
        options = "--delete-older-than 21d";
      };

      optimise = {
        automatic = true;
        dates = "Mon *-*-* 1:00:00";
      };
    };

  system.autoUpgrade = mkIf cfg.autoUpgrade {
    enable = true;
    flake = "github:JManch/nixos";
    operation = "boot";
    dates = "Mon *-*-* 02:00:00";
    randomizedDelaySec = "2hours";
  };

  systemd.services."nix-gc".unitConfig.ConditionACPower = mkIf (device.type == "laptop") true;

  systemd.services."nix-optimise" = {
    after = [ "nix-gc.service" ];
    unitConfig.ConditionACPower = mkIf (device.type == "laptop") true;
  };

  systemd.services."nixos-upgrade" = mkIf cfg.autoUpgrade {
    after = [
      "nix-optimise.service"
      "nix-gc.service"
    ];
    unitConfig.ConditionACPower = mkIf (device.type == "laptop") true;
  };

  ns.services = mkIf cfg.autoUpgrade {
    successNotifyServices.nixos-upgrade = {
      discord.enable = true;
      discord.var = "UPGRADE";
      email.enable = false;
    };

    failureNotifyServices.nixos-upgrade = {
      discord.enable = true;
      discord.var = "UPGRADE";
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
  systemd.tmpfiles.rules = mkIf impermanence.enable [
    "d /var/nix-tmp 0755 root root - -"
    "d /persist/var/nix-tmp 0755 root root - -"
  ];

  programs.command-not-found.enable = false;
  programs.nix-index = {
    # Nix-index doesn't work with cross compilation
    enable = with pkgs.stdenv; hostPlatform == buildPlatform;
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

  ns.persistence.files = mkIf cfg.builder.enable [
    "/etc/nix/nix_store_ed25519_key"
    "/etc/nix/nix_store_ed25519_key.pub"
  ];
}
