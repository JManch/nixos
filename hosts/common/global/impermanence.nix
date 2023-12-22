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
      "/var/lib/bluetooth"
      "/var/db/sudo/lectured"
    ];
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/machine-id"
      "/etc/adjtime"
    ];
    users.joshua = {
      directories = [
        "Documents"
        "Downloads"
        "Desktop"
        "Pictures"
        "Music"
        "Videos"
        "Repos"
        ".config/nixos"
        ".cache/nix"
        { directory = ".ssh"; mode = "0700"; }
      ];
      files = [
        ".zcompdump"
        ".zsh_history"
      ];
    };
  };
}
