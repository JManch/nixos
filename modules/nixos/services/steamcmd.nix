{
  lib,
  pkgs,
  config,
  ...
}:
{
  users.groups."steamcmd" = { };
  users.users."steamcmd" = {
    isSystemUser = true;
    group = "steamcmd";
  };

  # In game service add:
  # wants = [ "steamcmd@<APP_ID>.service" ]; (wants so that game still attempts start if update fails)
  # after = [ "steamcmd@<APP_ID>.service" ];
  systemd.services."steamcmd@" = {
    description = "Install or update Steam app %i";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = lib.${lib.ns}.hardeningBaseline config {
      Type = "oneshot";
      User = config.users.users.steamcmd.name;
      Environment = "HOME=%S/steamcmd"; # steamcmd boostraps into $HOME/.local/share/Steam
      StateDirectory = "steamcmd";
      StateDirectoryMode = "0711";
      ExecStart = "${lib.getExe pkgs.steamcmd} +force_install_dir /var/lib/steamcmd/apps/%i +login anonymous +app_update %i validate +quit";
      TimeoutStartSec = 3600; # allow time for updates

      DynamicUser = false;
      MemoryDenyWriteExecute = false;
      ProtectProc = "default";
      ProcSubset = "all";
      RestrictNamespaces = "user mnt"; # for steam-run's bubblewrap
      SystemCallArchitectures = "native x86"; # steamcmd is 32-bit
      SystemCallFilter = [ ]; # bubblewrap needs all syscalls
      UMask = "0022";
    };
  };

  # Example for game that needs steamworks sdk:
  # systemd.services."mygame" = {
  #   requires = [
  #     "steamcmd@<APP_ID>.service"
  #     "steamcmd@1007.service"
  #   ];
  #   after = [
  #     "steamcmd@<APP_ID>.service"
  #     "steamcmd@1007.service"
  #   ];
  #   preStart = ''
  #     mkdir -p "$HOME/.steam/sdk64"
  #     ln -sfn /var/lib/steamcmd/apps/1007/linux64/steamclient.so "$HOME/.steam/sdk64/steamclient.so"
  #   '';
  # };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/steamcmd";
    user = "steamcmd";
    group = "steamcmd";
    mode = "0711";
  };
}
