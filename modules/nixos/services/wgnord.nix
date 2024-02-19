{ lib, config, ... }:
let
  cfg = config.modules.services.wgnord;
in
lib.mkIf cfg.enable
{
  age.secrets.nordToken.file = ../../../secrets/nordvpn/token.age;

  services.wgnord = {
    enable = true;
    tokenFile = config.age.secrets.nordToken.path;
    country = cfg.country;
  };

  programs.zsh = {
    shellAliases = {
      vpn-up = "sudo systemctl start wgnord";
      vpn-down = "sudo systemctl stop wgnord";
    };
  };
}
