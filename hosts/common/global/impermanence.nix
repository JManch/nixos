{ lib, inputs, config, ... }: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/tmp"
      "/var/lib/systemd"
      "/var/lib/nixos"
      "/var/db/sudo/lectured"
      "/etc/ssh"
    ];
    files = [
      "/etc/machine-id"
      "/etc/adjtime"
    ];
  };
}
