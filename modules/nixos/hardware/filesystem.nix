{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    utils
    mkVMOverride
    nameValuePair
    filter
    elemAt
    unique
    splitString
    getExe
    getExe'
    mkForce
    mkMerge
    replaceStrings
    ;
  cfg = config.modules.hardware.fileSystem;
in
{
  assertions = utils.asserts [
    (cfg.tmpfsTmp -> !config.modules.system.impermanence.enable)
    "Tmp on tmpfs should not be necessary if impermanence is enabled"
  ];

  zramSwap.enable = true;

  # We use legacy ZFS mountpoints and use systemd to mount them rather than
  # ZFS' auto-mount. Might want to switch to using the ZFS native mountpoints
  # and mounting with the zfs-mount-generator in the future.
  # https://github.com/NixOS/nixpkgs/issues/62644
  systemd.services.zfs-mount.enable = false;

  boot = {
    loader.efi.canTouchEfiVariables = true;
    tmp.useTmpfs = cfg.tmpfsTmp;

    # ZFS does not always support the latest kernel
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    zfs.package = mkIf cfg.unstableZfs pkgs.zfs_unstable;

    # Set zfs devNodes to "/dev/disk/by-path" for VM installs to fix zpool
    # import failure. Make sure the disks in disko have VM install overrides
    # configured.
    # https://discourse.nixos.org/t/cannot-import-zfs-pool-at-boot/4805
    zfs.devNodes = mkIf inputs.vmInstall.value (mkVMOverride "/dev/disk/by-path");

    supportedFilesystems = [ "zfs" ];

    loader.timeout = mkIf cfg.extendedLoaderTimeout 30;
    loader.systemd-boot = {
      enable = true;
      editor = false;
      consoleMode = "auto";
      configurationLimit = 20;
    };

    initrd.systemd = mkMerge [
      { enable = true; }

      # Modify the ZFS import service to allow passwordless native ZFS
      # encryption unlocking using a passphrase decrypted with TPM 2.0
      (
        let
          nixosUtils = import "${inputs.nixpkgs}/nixos/lib/utils.nix" { inherit lib pkgs config; };
          zfsFilesystems = filter (x: x.fsType == "zfs") config.system.build.fileSystems;
          datasetToPool = x: elemAt (splitString "/" x) 0;
          fsToPool = fs: datasetToPool fs.device;
          rootPools = unique (map fsToPool (filter nixosUtils.fsNeededForBoot zfsFilesystems));
        in
        mkIf (cfg.encrypted && cfg.zfsPassphraseCred != null) {
          # We have to add our custom script to storePaths so that it's available
          # in initrd. This isn't needed when using the "script" systemd
          # attribute as it makes a job script that gets automatically added to
          # storePaths.
          storePaths = map (
            pool: config.boot.initrd.systemd.services."zfs-import-${pool}".serviceConfig.ExecStart
          ) rootPools;

          services = lib.listToAttrs (
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
                customImportScript = getExe (
                  pkgs.writeShellScriptBin "zfs-import-${pool}-custom" (
                    replaceStrings [ "prompt )\n      tries=3\n      success=false\n" ]
                      [
                        # bash
                        ''
                          # indent anchor
                              prompt )
                                # Attempt to load the passphrase from systemd-creds
                                # then fall back to manual passphrase entry.
                                ${systemd-creds} cat zfs-passphrase | ${zfs} load-key "$ds" \
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
                serviceConfig = {
                  # Generate with: systemd-ask-password -n | systemd-creds encrypt --with-key=tpm2 --name=zfs-passphrase -p - -
                  SetCredentialEncrypted = "zfs-passphrase:${cfg.zfsPassphraseCred}";
                  ExecStart = mkForce customImportScript;
                };
              }
            ) rootPools
          );
        }
      )
    ];
  };

  services.zfs = {
    trim.enable = cfg.trim;
    autoScrub.enable = true;
  };

  programs.zsh.shellAliases = {
    boot-bios = "systemctl reboot --firmware-setup";
  };
}
