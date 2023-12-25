{
  inputs,
  username,
  ...
}: {
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
    users.${username} = {
      directories = [
        "downloads"
        "pictures"
        "music"
        "videos"
        "repos"
        "files"
        ".config/nixos"
        ".cache/nix"
        ".local/state/zsh"
        ".cache/zsh"
        {
          directory = ".ssh";
          mode = "0700";
        }
      ];
      files = [];
    };
  };
}
