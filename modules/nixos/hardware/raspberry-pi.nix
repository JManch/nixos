{
  lib,
  cfg,
  inputs,
  ...
}:
{
  imports = with inputs.raspberry-pi-nix.nixosModules; [
    raspberry-pi
    sd-image
  ];

  # I'm not sure why raspberry-pi-nix overlays this. Their overlay breaks cross
  # compilation and booting (by removing the bigger kernel patch). Using the
  # nixpkgs version fixes both problems.
  nixpkgs.overlays = lib.mkAfter [
    (_: _: {
      uboot-rpi-arm64 = cfg.uboot.package;
    })
  ];

  raspberry-pi-nix = {
    # WARN: Might want to disable this on newer pis (5+)
    uboot.enable = cfg.uboot.enable;
    # Has to be disabled for cross compilation to work
    pin-inputs.enable = false;
  };

  # Build fails without this disabled
  boot.initrd.systemd.tpm2.enable = false;

  # zfs has a dependency on samba which is broken under cross compilation
  boot.supportedFilesystems.zfs = lib.mkForce false;

  sdImage.compressImage = false;
}
