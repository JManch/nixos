{ lib
, pkgs
, config
, hostname
, ...
}:
let
  inherit (lib) mkIf utils getExe';
  inherit (config.device) gpu;
  cfg = config.modules.services.lact;
  gpuId = "1002:744C-1EAE:7905-0000:09:00.0";
in
# This module is specifically for 7900XT on NCASE-M1 host
mkIf cfg.enable
{
  assertions = utils.asserts [
    (hostname == "ncase-m1")
    "Lact is only intended to work on host 'ncase-m1'"
    (gpu.type == "amd")
    "Lact requires an AMD gpu"
  ];

  # WARN: Disable this if you experience flickering or general instability
  # https://wiki.archlinux.org/title/AMDGPU#Boot_parameter
  boot.kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];

  services.lact = {
    enable = true;

    # Can't use nix yaml because the keys for fan curve have to be integers
    settings = /*yaml*/ ''
      daemon:
        log_level: info
        admin_groups:
        - wheel
        - sudo
        disable_clocks_cleanup: false
      apply_settings_timer: 5
      gpus:
        ${gpuId}:
          fan_control_enabled: true
          fan_control_settings:
            mode: curve
            static_speed: 0.5
            temperature_key: edge
            interval_ms: 500
            curve:
              50: 0.0
              60: 0.0
              70: 0.5
              75: 0.6
              80: 0.65
          pmfw_options:
            acoustic_limit: 3300
            acoustic_target: 2000
            minimum_pwm: 15
            target_temperature: 80
          # Run at 257 for slightly better performance but louder fans
          power_cap: 231.0
          performance_level: manual
          max_core_clock: 2394
          voltage_offset: -50
          power_profile_mode_index: 0
          power_states:
            core_clock:
            - 0
            - 1
            - 2
            memory_clock:
            - 0
            - 1
            - 2
            - 3
    '';
  };

  modules.programs.gaming.gamemode =
    let
      ncat = getExe' pkgs.nmap "ncat";
      confirm = ''echo '{"command": "confirm_pending_config", "args": {"command": "confirm"}}' | ${ncat} -U /run/lactd.sock'';
    in
    {
      startScript = ''
        echo '{"command": "set_power_profile_mode", "args": {"id": "${gpuId}", "index": 1}}' | ${ncat} -U /run/lactd.sock
        ${confirm}
      '';
      stopScript = ''
        echo '{"command": "set_power_profile_mode", "args": {"id": "${gpuId}", "index": 0}}' | ${ncat} -U /run/lactd.sock
        ${confirm}
      '';
    };
}
