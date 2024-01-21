{ lib
, pkgs
, config
, username
, ...
}:
lib.mkIf config.modules.system.virtualisation.enable {
  virtualisation = {
    libvirtd.enable = true;

    # Only applies when building VM with nixos-rebuild build-vm
    vmVariant = {
      virtualisation = {
        # TODO: Make this modular based on host spec
        memorySize = 4096; # Use 2048MiB memory.
        cores = 8;
      };
    };
  };
  programs.virt-manager.enable = true;
  users.users."${username}".extraGroups = [ "libvirtd" ];

  environment = {
    persistence."/persist".directories = [
      "/var/lib/libvirt"
    ];
    variables = {
      # Allows nixos-rebuild build-vm graphical session
      # https://github.com/NixOS/nixpkgs/issues/59219
      QEMU_OPTS = "-device virtio-vga-gl -display gtk,show-menubar=off,gl=on";
    };
  };
}
