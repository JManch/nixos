{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    getExe
    getExe'
    ;
  cfg = config.services.wgnord;
  template = pkgs.writeText "template.conf" cfg.template;
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
      description = ''
        The country which wgnord will try to connect to from
        https://github.com/phirecc/wgnord/blob/master/countries.txt
      '';
    };

    template = mkOption {
      type = types.lines;
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
    systemd.services.wgnord = {
      unitConfig = {
        Description = "Nord Wireguard VPN";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        StartLimitBurst = 3;
        StartLimitIntervalSec = 30;
      };

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "wgnord";
        ExecStartPre = [
          "${getExe' pkgs.coreutils "ln"} -fs ${template} /var/lib/wgnord/template.conf"
          "${getExe' pkgs.bash "sh"} -c '${getExe cfg.package} login \"$(<${cfg.tokenFile})\"'"
        ];
        ExecStart = "${getExe cfg.package} connect \"${cfg.country}\"";
        ExecStop = "-${getExe cfg.package} disconnect";
        Restart = "on-failure";
        RestartSec = 10;
        RemainAfterExit = "yes";
      };
    };
  };
}
