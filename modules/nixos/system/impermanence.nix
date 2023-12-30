{ inputs
, username
, lib
, config
, ...
}:
let
  cfg = config.modules.system.impermanence;
  optionals = lib.lists.optionals;
  optional = lib.lists.optional;
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  programs.zsh.shellAliases = {
    # List all files that will be lost on shutdown
    impermanence = ''sudo fd --base-directory / -a -tf -H -E "{$(findmnt -n -o TARGET --list -t zfs | sed 's/^.//' | tr '\n' ',' | sed 's/.$//'),proc,sys,run,dev,tmp,boot}"'';
  };

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
    # It's not ideal to define home persistance here but has to be done
    # for performance reasons https://redd.it/15xxqlj
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
        ".cache/fontconfig"
        {
          directory = ".ssh";
          mode = "0700";
        }
      ]
      ++ optionals cfg.zsh [
        ".local/state/zsh"
        ".cache/zsh"
      ]
      ++ optionals cfg.firefox [
        ".mozilla"
        ".cache/mozilla"
      ]
      ++ optionals cfg.spotify [
        ".cache/spotify"
        ".config/spotify"
      ]
      ++ optionals cfg.neovim [
        ".config/nvim"
        ".local/share/nvim"
        ".local/state/nvim"
        ".cache/nvim"
      ]
      ++ optional (config.device.gpu == "nvidia") ".cache/nvidia"
      ++ optional cfg.swww ".cache/swww"
      ++ optional cfg.discord ".config/discord"
      ++ optional cfg.starship ".cache/starship";
      files = optional cfg.lazygit ".config/lazygit/state.yml";
    };
  };
}
