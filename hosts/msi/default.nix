{ ns, ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  ${ns} = {
    device = {
      type = "desktop";
      ipAddress = "192.168.88.244";
      memory = 1024 * 16;

      cpu = {
        name = "i7 6700k";
        type = "intel";
        cores = "8";
      };

      gpu = {
        name = "RTX 2070";
        type = "nvidia";
      };

      monitors = [
        {
          name = "placeholder";
          number = 1;
          refreshRate = 60;
          width = 1920;
          height = 1080;
          position.x = 0;
          position.y = 0;
        }
      ];
    };

    core = {
      priviledgedUser = false;
      homeManager.enable = true;
      autoUpgrade = true;
    };

    hardware = {
      secureBoot.enable = true;

      fileSystem = {
        type = "zfs";
        tmpfsTmp = true;
        zfs.trim = true;
        zfs.encryption.passphraseCred = "DHzAexF2RZGcSwvqCLwg/iAAAAABAAAADAAAABAAAAC16pMdY9oxIerp+s0AAAAAgAAAAAAAAAAEACMA0AAAACAAAAAAfgAg4k2dsjF+wZuYCEqT6S2Zz+EMbx5/anyDHmQA0b39wnEAEAmwSRPdAugtok+xmWBxESTiPDbO3+lhsMjO6gxDzY6D0wVA7yYGm07S4ItovBfJmhqgogNQnHU6OeP7YRCZG9Uiv2FR6IsxScXV+O9zoaOAYdGE8NHHPFwLVgBOAAgACwAABBIAICOggjc/UCURP3ANnxcEjAQGuMkf9R6UX+qSLkbyanxlABAAIACrd9GrmOizSNxJUSEGb5W4qxfBbhad5l7pjQlHTHfaI6CCNz9QJRE/cA2fFwSMBAa4yR/1HpRf6pIuRvJqfGUAAAAAc9UPthPU99J82DLI9jq+roZxKkk/py9z1SwOO+8OSot43Wst4a/5bIJ3K6yKTHfSwvF1gWIHUcgJ6PykdFkugwtPo5nwSId+53skhNkP3ef/EtiPMxdSJSrPJESmiHJWbpCJEG5DeaWJWjZYzCl2LH77RTZafQgEqTySAdKdR2/IckigvDW/dUsSeodKYLkA";
      };

      printing.client = {
        enable = true;
        serverAddress = "homelab.lan";
      };
    };

    system = {
      audio.enable = true;
      ssh.server.enable = true;
      networking.wiredInterface = "enp3s0";

      desktop = {
        enable = true;
        # Suspend is very close to being stable but it sometimes causes
        # applications to crash and the system sometimes gets stuck in a
        # suspend loop
        suspend.enable = false;
        desktopEnvironment = "gnome";
      };
    };

    programs = {
      gaming = {
        enable = true;
        steam.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      scrutiny.collector.enable = true;

      restic = {
        enable = true;
        backupSchedule = "*-*-* 14:00:00";
        runMaintenance = false;
      };
    };
  };
}
