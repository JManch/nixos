{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.services.wgnord;
in
{
  options.services.wgnord = {
    enable = mkEnableOption "wgnord";
    package = mkOption {
      type = types.package;
      default = pkgs.wgnord;
      description = "The wgnord package to install";
    };
    tokenFile = mkOption {
      type = types.path;
      default = null;
      description = "Path to a file containing your NordVPN authentication token";
    };
    country = mkOption {
      type = types.str;
      default = "United States";
      description = "The country which wgnord will try to connect to from https://github.com/phirecc/wgnord/blob/master/countries.txt";
    };
    template = mkOption {
      type = types.str;
      default = ''
        [Interface]
        PrivateKey = PRIVKEY
        Address = 10.5.0.2/32
        MTU = 1350
        DNS = 103.86.96.100 103.86.99.100

        [Peer]
        PublicKey = SERVER_PUBKEY
        AllowedIPs = 0.0.0.0/0, ::/0
        Endpoint = SERVER_IP:51820
        PersistentKeepalive = 25
      '';
      description = "The Wireguard config";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.wgnord ];

    systemd.services.wgnord = {
      unitConfig = {
        Description = "Nord Wireguard VPN";
        After = [ "network.target" ];
      };
      serviceConfig = {
        Type = "oneshot";
        # https://discourse.nixos.org/t/creating-directories-and-files-declararively/9349/2
        StateDirectory = "wgnord";
        ExecStartPre = [
          "-${pkgs.coreutils}/bin/ln -s /etc/wgnord/template.conf /var/lib/wgnord/template.conf"
          # The login command is broken, returns exit code 1 even on success
          # We use '-' prefix to ignore this failure
          "-${pkgs.bash}/bin/sh -c '${cfg.package}/bin/wgnord login \"$(<${cfg.tokenFile})\"'"
        ];
        ExecStart = "${cfg.package}/bin/wgnord connect \"${cfg.country}\"";
        ExecStop = "-${cfg.package}/bin/wgnord disconnect";
        Restart = "on-failure";
        RestartSec = "1s";
        RemainAfterExit = "yes";
      };
    };

    environment.etc."wgnord/template.conf".text = cfg.template;

    systemd.tmpfiles.rules = [
      "d /etc/wireguard 755 root root"
      "f /etc/wireguard/wgnord.conf 600 root root"
    ];
  };
}
