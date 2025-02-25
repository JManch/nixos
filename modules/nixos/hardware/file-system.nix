# To see the scripts generated by disko inspect the following derivations:

# WARN: The format script does not remove existing partitions on the disk. In
# most cases you'd want to run the destroy script before format.

# - config.system.build.diskoScript (runs destroy, format, mount)
# - config.system.build.formatScript
# - config.system.build.destroyScript
# - config.system.build.mountScript (useful for rescues)
{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkIf
    mkVMOverride
    nameValuePair
    filter
    elemAt
    unique
    splitString
    getExe
    getExe'
    mkForce
    listToAttrs
    singleton
    optionalString
    replaceStrings
    mkEnableOption
    mkOption
    types
    mapAttrsToList
    hasAttr
    any
    attrValues
    ;
  inherit (config.${ns}.system) impermanence;
  inherit (config.${ns}.hardware) raspberryPi;
in
[
  {
    guardType = "custom";
    enableOpt = false;

    opts = {
      tmpfsTmp = mkEnableOption "tmp on tmpfs";
      extendedLoaderTimeout = mkEnableOption ''
        an extended loader timeout of 30 seconds. Useful for switching to old
        generations on headless machines.
      '';

      type = mkOption {
        type = types.enum [
          "zfs"
          "ext4"
          "sd-image"
        ];
        default = null;
        description = "The type of filesystem on this host";
      };

      ext4.trim = removeAttrs (mkEnableOption "ext4 automatic trimming") [ "default" ];

      zfs = {
        unstable = mkEnableOption "unstable ZFS";
        trim = removeAttrs (mkEnableOption "ZFS automatic trimming") [ "default" ];

        encryption = {
          enable = mkOption {
            type = types.bool;
            readOnly = true;
            # Check for any pool datasets with encryption enable or child
            # datasets with encryption enabled
            default = any (v: v == true) (
              mapAttrsToList (
                _: pool:
                (hasAttr "encryption" pool.rootFsOptions)
                || (any (dataset: hasAttr "encryption" dataset.options) (attrValues pool.datasets))
              ) config.disko.devices.zpool
            );
            description = ''
              Whether the file system uses ZFS disk encryption. Derived from disko
              config.
            '';
          };

          passphraseCred = mkOption {
            type = with types; nullOr lines;
            default = null;
            description = ''
              Encrypted ZFS passphrase credential generated with
              `systemd-ask-password -n | systemd-creds encrypt --with-key=tpm2
              --name=zfs-passphrase -p - -`
            '';
          };
        };
      };

      swap =
        let
          inherit (config.${ns}.device) memory;
        in
        {
          enable = mkEnableOption "swap" // {
            default = cfg.type != "zfs" && cfg.type != "sd-image" && memory <= 4 * 1024;
          };

          size = mkOption {
            type = types.int;
            default =
              if memory <= 2 * 1024 then
                memory * 2
              else if memory <= 8 * 1024 then
                memory
              else
                1024 * 4;
            description = "Size of swap file in megabytes";
          };
        };
    };

    assertions = lib.${ns}.asserts [
      (cfg.type != null)
      "Filesystem type must be set"
      (cfg.tmpfsTmp -> !config.${ns}.system.impermanence.enable)
      "Tmp on tmpfs should not be necessary if impermanence is enabled"
    ];

    zramSwap.enable = true;
    swapDevices = mkIf cfg.swap.enable (singleton {
      device = "${optionalString impermanence.enable "/persist"}/var/lib/swapfile";
      size = cfg.swap.size;
    });

    boot = {
      initrd.systemd.enable = true;
      tmp.useTmpfs = cfg.tmpfsTmp;

      loader = mkIf (!raspberryPi.enable) {
        efi.canTouchEfiVariables = true;
        timeout = mkIf cfg.extendedLoaderTimeout 30;
        systemd-boot = {
          enable = true;
          editor = false;
          consoleMode = "auto";
          configurationLimit = 10;
        };
      };
    };

    programs.zsh.shellAliases = {
      boot-bios = "systemctl reboot --firmware-setup";
    };
  }

  (mkIf (cfg.type == "ext4") {
    services.fstrim.enable = cfg.ext4.trim;
  })

  (mkIf (cfg.type == "zfs") {
    # We use legacy ZFS mountpoints and use systemd to mount them rather than
    # ZFS' auto-mount. Might want to switch to using the ZFS native mountpoints
    # and mounting with the zfs-mount-generator in the future.
    # https://github.com/NixOS/nixpkgs/issues/62644
    systemd.services.zfs-mount.enable = false;

    services.zfs = {
      trim.enable = cfg.zfs.trim;
      autoScrub.enable = true;
    };

    boot = {
      # ZFS does not always support the latest kernel so safest option is to
      # default to LTS kernel on all hosts. If a host needs the latest kernel
      # for hardware support it should be overriden in their hardware
      # configuration.
      kernelPackages = pkgs.linuxPackages;

      supportedFilesystems.zfs = true;
      zfs.package = mkIf cfg.zfs.unstable pkgs.zfs_unstable;

      # Set zfs devNodes to "/dev/disk/by-path" for VM installs to fix zpool
      # import failure. Make sure the disks in disko have VM install overrides
      # configured.
      # https://discourse.nixos.org/t/cannot-import-zfs-pool-at-boot/4805
      zfs.devNodes = mkIf inputs.vmInstall.value (mkVMOverride "/dev/disk/by-path");

      # Modify the ZFS import service to allow passwordless native ZFS
      # encryption unlocking using a passphrase decrypted with TPM 2.0
      initrd.systemd =
        let
          nixosUtils = import "${inputs.nixpkgs}/nixos/lib/utils.nix" { inherit lib pkgs config; };
          zfsFilesystems = filter (x: x.fsType == "zfs") config.system.build.fileSystems;
          datasetToPool = x: elemAt (splitString "/" x) 0;
          fsToPool = fs: datasetToPool fs.device;
          rootPools = unique (map fsToPool (filter nixosUtils.fsNeededForBoot zfsFilesystems));
        in
        mkIf (cfg.zfs.encryption.enable && cfg.zfs.encryption.passphraseCred != null) {
          # We have to add our custom script to storePaths so that it's available
          # in initrd. This isn't needed when using the "script" systemd
          # attribute as it makes a job script that gets automatically added to
          # storePaths.
          storePaths = map (
            pool: config.boot.initrd.systemd.services."zfs-import-${pool}".serviceConfig.ExecStart
          ) rootPools;

          services = listToAttrs (
            map (
              pool:
              let
                systemd = config.boot.initrd.systemd.package;
                systemd-creds = getExe' systemd "systemd-creds";
                zfs = "${config.boot.zfs.package}/sbin/zfs";

                # This isn't nice but it's the best way I can think of achieving this
                # without redefining the entire ZFS module or maintaining a nixpkgs
                # fork. Hopefully something like https://github.com/NixOS/nixpkgs/pull/251715
                # gets merged eventually. The upstream systemd service defines
                # the script using `systemd.service.<name>.script`. To avoid
                # infinite recursion we override ExecStart with a new script
                # containing a modified version of the original script.

                # Generate with passphrase creds with:
                # systemd-ask-password -n | systemd-creds encrypt --with-key=tpm2 --name=zfs-passphrase - -
                # PCR 11 doesn't seem to work unfortunately
                customImportScript = getExe (
                  pkgs.writeShellScriptBin "zfs-import-${pool}-custom" (
                    replaceStrings
                      [ "prompt )\n      tries=3\n      success=false\n" ]
                      [
                        # bash
                        ''
                          # indent anchor
                              prompt )
                                # Attempt to load the passphrase from systemd-creds then fallback to manual
                                # passphrase entry

                                if [ ! -v tpm_passphrase ]; then
                                  # We need to decrypt here instead of using SetCredentialEncrypted so that
                                  # import will still work if decryption fails. For some reason if
                                  # SetCredentialEncrypted creds fail to decrypt, the entire service fails.

                                  # Store the passphrase in a variable so that the same passphrase can be used to
                                  # decrypt multiple datasets. Obviously this makes the assumption that all our
                                  # datasets are encrypted with the same passphrase.
                                  tpm_passphrase="$(${systemd-creds} decrypt --name= - - <<< "${cfg.zfs.encryption.passphraseCred}" || true)";
                                fi

                                echo "$tpm_passphrase" | ${zfs} load-key "$ds" \
                                  && success=true || success=false
                                tries=10
                        ''
                      ]
                      # Prepend the script with "set -e" to emulate upstream's `makeJobScript`
                      ("set -e\n" + config.boot.initrd.systemd.services."zfs-import-${pool}".script)
                  )
                );
              in
              nameValuePair "zfs-import-${pool}" {
                after = [ "tpm2.target" ];
                serviceConfig.ExecStart = mkForce customImportScript;
              }
            ) rootPools
          );
        };
    };
  })
]
