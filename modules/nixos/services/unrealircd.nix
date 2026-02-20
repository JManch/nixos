{ lib, pkgs }:
let
  inherit (lib) ns getExe;
in
{
  systemd.services."unrealircd" = {
    description = "UnrealIRCd IRC server";

    serviceConfig = {
      ExecStart = "${getExe pkgs.${ns}.unrealircd} -F";
      RuntimeDirectory = "unrealircd";
      StateDirectory = "unrealircd";
      CacheDirectory = "unrealircd";
      LogsDirectory = "unrealircd";

      ProtectSystem = "strict";
    };

    install.WantedBy = [ "default.target" ];
  };
}
