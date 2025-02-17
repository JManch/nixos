# Setup steps:
# 1. Make sure openRegistration is enabled on my server (disable once registered)
# 2. `atuin login`
# 3. Login with creds in vaultwarden
# 4. `systemctl restart --user atuin-daemon.service`
# 5. `atuin store purge`
# 6. `atuin store verify`
# 7. `atuin sync -f`

# Steps for full reset if things are broken: https://github.com/atuinsh/atuin/issues/2096#issuecomment-2154989475
{
  lib,
  cfg,
  pkgs,
  inputs,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkOption
    types
    getExe
    ;
  inherit (osConfig.${ns}.services) atuin-server;
in
{
  opts.syncAddress = mkOption {
    type = types.str;
    default =
      if atuin-server.enable or false then
        "http://127.0.0.1:${toString atuin-server.port}"
      else
        "https://atuin.${inputs.nix-resources.secrets.fqDomain}";
    description = ''
      Address of the remote atuin sync server
    '';
  };

  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      dotfiles.enabled = false;
      auto_sync = true;
      update_check = false;
      sync_address = cfg.syncAddress;
      sync_frequency = "10m";
      enter_accept = false;
      keymap_mode = "vim-insert";
      inline_height = 15;
      show_preview = false;
      show_help = false;
      show_tabs = false;

      # WARN: The daemon service must be manually restarted after logging in
      # otherwise stuff is encrypted with the wrong key
      daemon = {
        enabled = true;
        systemd_socket = true;
        socket_path = "/run/user/1000/atuin.sock";
      };
    };
  };

  systemd.user.sockets.atuin-daemon = {
    Unit.Description = "Atuin Daemon Socket";

    Socket = {
      ListenStream = "%t/atuin.sock";
      SocketMode = "0600";
    };

    Install.WantedBy = [ "sockets.target" ];
  };

  systemd.user.services.atuin-daemon = {
    Unit = {
      Description = "Atuin Daemon";
      Requires = [ "atuin-daemon.socket" ];
      After = [ "atuin-daemon.socket" ];
    };

    Service = {
      Slice = "background.slice";
      Environment = [ "ATUIN_LOG=info" ];
      ExecStart = "${getExe pkgs.atuin} daemon";
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Disable zsh history
  programs.zsh.initExtra = ''
    unset HISTFILE
  '';

  nsConfig.persistence.directories = [ ".local/share/atuin" ];
}
