{ pkgs
, config
, ...
}:
let
  chipID = "8620";
  gpuTemp = pkgs.writeShellScript "gpu-temp" ''
    temp=$(${config.hardware.nvidia.package.bin}/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    echo "''${temp}000"
  '';
in
{
  environment.systemPackages = with pkgs; [
    lm_sensors
    config.boot.kernelPackages.it87
  ];

  boot = {
    kernelModules = [ "it87" ];
    extraModulePackages = with config.boot.kernelPackages; [ it87 ];
    /*
      The chipID is a mystery. 0x8688 matches the hardware of the motherboard and
      worked perfectly on an old deployment but has broken for an unknown reason.
      Works fine on Arch, just not on Nix. Using 0x8620 instead as it still
      provides fan speeds but is missing a bunch of temp sensors. If fan control
      ever breaks it's probably because of this.

      Update: did a fresh install on the Arch drive and 0x8688 works again.
    */
    extraModprobeConfig = ''
      options it87 ignore_resource_conflict=1 force_id=0x${chipID}
    '';
  };

  /*
    CPU_FAN: AIO pump. Only provides a reading, cannot control.

    SYS_FAN1: Intake GPU fans on the bottom of the case.

    SYS_FAN2: Intake CPU radiator fans on the side of the case.
  */
  environment.etc."sensors.d/gigabyte-b550i.conf".text = ''
    chip "it${chipID}-*"
        label fan1 "CPU_FAN"
        label fan2 "SYS_FAN1"
        label fan3 "SYS_FAN2"
  '';

  environment.persistence."/persist".files = [ "/etc/fan2go/fan2go.db" ];

  programs.fan2go = {
    enable = true;
    systemd.enable = true;
    settings = {
      fans = [
        {
          id = "gpu";
          hwmon = {
            platform = "it${chipID}-*";
            rpmChannel = 2;
          };
          neverStop = false;
          curve = "gpu_curve";
        }
        {
          id = "cpu";
          hwmon = {
            platform = "it${chipID}-*";
            rpmChannel = 3;
          };
          neverStop = false;
          curve = "cpu_curve";
        }
      ];
      sensors = [
        {
          id = "gpu_temp";
          cmd = {
            exec = "${pkgs.bash}/bin/sh";
            args = [ "${gpuTemp.outPath}" ];
          };
        }
        {
          id = "cpu_temp";
          hwmon = {
            platform = "k10temp-*";
            index = 1;
          };
        }
      ];
      curves = [
        {
          id = "gpu_curve";
          linear = {
            sensor = "gpu_temp";
            min = 40;
            max = 90;
            steps = [
              { "0" = 76; }
              { "40" = 76; }
              { "50" = 102; }
              { "60" = 128; }
              { "70" = 153; }
              { "76" = 184; }
              { "80" = 230; }
              { "90" = 255; }
            ];
          };
        }
        {
          id = "cpu_curve";
          linear = {
            sensor = "cpu_temp";
            min = 40;
            max = 90;
            steps = [
              { "0" = 51; }
              { "40" = 51; }
              { "50" = 77; }
              { "58" = 102; }
              { "62" = 130; }
              { "65" = 165; }
              { "70" = 204; }
              { "90" = 255; }
            ];
          };
        }
      ];
    };
  };
}
