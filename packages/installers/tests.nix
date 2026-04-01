lib: self: installerName: base: pkgs:
let
  inherit (lib)
    ns
    listToAttrs
    singleton
    modules
    nameValuePair
    ;

  mkTest =
    name: testHostOptions:
    let
      testHost =
        (lib.${ns}.mkHost name "joshua" pkgs.stdenv.hostPlatform.system [
          (modules.importApply ./test-host.nix testHostOptions)
        ]).value;
    in
    nameValuePair name {
      inherit testHost;
      test = pkgs.testers.runNixOSTest {
        name = "${installerName}-${name}-test";

        skipLint = true; # FIX: REMOVE THIS ONCE TEST IS FUNCTIONAL
        enableOCR = true;

        node = {
          inherit pkgs;
          pkgsReadOnly = false;
          specialArgs = {
            inherit lib self base;
          };
        };

        defaults = {
          virtualisation.diskSize = 8 * 1024;
          virtualisation.cores = 8;
          virtualisation.memorySize = 4 * 1024;
          virtualisation.diskImage = "./target.qcow2";

          nixpkgs.overlays = singleton (
            _: _: {
              ${ns}.bootstrap-kit = self.packages.${pkgs.stdenv.hostPlatform.system}.bootstrap-kit.override {
                bootstrapKit = "${self.inputs.nix-resources}/secrets/installer-test-bootstrap-kit.tar.age";
              };
            }
          );
        };

        nodes = {
          installer =
            { ... }:
            {
              imports = [
                (modules.importApply ../../hosts/installer {
                  hostPath = "packages.${pkgs.stdenv.hostPlatform.system}.${installerName}.passthru.testHosts";
                  vendorNixResources = true;
                })
              ];
              system.extraDependencies = [ testHost.config.system.build.toplevel ];
              users.users.root.hashedPasswordFile = lib.mkForce null;

              virtualisation.emptyDiskImages = [ 512 ];
              virtualisation.rootDevice = "/dev/vdb";
              virtualisation.fileSystems."/".autoFormat = true; # requires initrd.systemd.enable

              # Want to use systemd initrd because getting tests to run without
              # it is a pain. ISO image doesn't support it yet though:
              # Waiting on https://github.com/NixOS/nixpkgs/pull/291750
              # and https://github.com/NixOS/nixpkgs/issues/309190
              boot.initrd.systemd.enable = true;
            };

          target =
            { ... }:
            {
              # Upstream iso test uses these so might want them
              # virtualisation.useBootLoader = true;
              # virtualisation.useEFIBoot = true;
              virtualisation.useDefaultFilesystems = false;
              virtualisation.efi.keepVariables = false;

              virtualisation.fileSystems."/" = {
                device = "/dev/disk/by-label/this-is-not-real-and-will-never-be-used";
                fsType = "ext4";
              };
            };
        };

        testScript = ''
          installer.start()

          # FIX: This doesn't work
          # Decypt bootstrap-kit for agenix
          # installer.wait_for_text("Enter passphrase: ")
          # installer.send_chars("test\n")

          installer.wait_for_unit("multi-user.target")
          installer.succeed("echo hello")
          installer.succeed("udevadm settle")

          installer.send_chars("sudo install-host ${name} 2>&1 | tee >(systemd-cat -t nixos-install)\n")
          installer.wait_until_tty_matches("1", r"Use the flake this ISO was built with\? \(default is to fetch latest from GitHub\) \(y\/N\): ")
          installer.send_chars("y")
          installer.wait_until_tty_matches("1", "Enter passphrase: ")
          installer.send_chars("test\n")
          installer.wait_until_tty_matches("1", r"Are you installing this host in a virtual machine\? \(y\/N\): ")
          installer.send_chars("y")
          installer.wait_until_tty_matches("1", r"Enter the address of a remote build host \(leave empty to build locally\): ")
          installer.send_chars("\n")
          installer.wait_until_tty_matches("1", r"Are you sure you want to proceed\? \(y\/N\): ")
          installer.send_chars("y")
          installer.wait_until_tty_matches("1", "installation finished!")

          installer.succeed("umount -R /mnt")
          installer.succeed("sync")
          installer.shutdown()
          target.state_dir = installer.state_dir

          target.start()
          target.wait_for_unit("multi-user.target")

          # with subtest("Check whether keys were installed correctly"):
          # TODO: Add extra specific tests here depending on the type of test e.g. for impermanence
        '';
      };
    };

in
listToAttrs [
  (mkTest "minimal" { })
  # (mkTest "minimal-impermanence" { impermanence = true; })
]
