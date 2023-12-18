{ pkgs, config, ... }: {
  environment.systemPackages = with pkgs; [
    lm_sensors
  ];

  /*
  CPU_FAN: AIO pump. Only provides a reading, cannot control.

  SYS_FAN1: Intake GPU fans on the bottom of the case.

  SYS_FAN2: Intake CPU radiator fans on the side of the case.

  WARNING: The temperature sensor labels are complete guesses.
  */
  environment.etc."sensors.d/gigabyte-b550i.conf".text = ''
    chip "it8688-*"
        label fan1 "CPU_FAN"
        label fan2 "SYS_FAN1"
        label fan3 "SYS_FAN2"
        label temp1 "System 1"
        label temp2 "VSOC MOS"
        label temp3 "CPU"
        label temp5 "VRM MOS"
        label temp6 "PCH"
  '';

  programs.fan2go = {
    enable = true;
    systemd.enable = false;
    settings = {
      fans = {
        id = "cpu_fan";
        hwmon = {
          platform = "it8688-*";
          rpmChannel = 2;
          pwmChannel = 2;
        };
        neverStop = true;
        curve = "cpu_curve";
      };
      sensors = {
        id = "gpu_temp";
        cmd = {
          # exec = "${config.hardware.nvidia.package}/bin/nvidia-smi";
        };
      };
      curves = {
        id = "cpu_curve";
        linear = {
          sensor = "cpu_package";
          min = 40;
          max = 80;
        };
      };
    };
  };

}
