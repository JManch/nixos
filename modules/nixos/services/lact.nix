{ lib
, pkgs
, config
, hostname
, ...
}:
let
  inherit (lib) mkIf utils getExe' getExe concatMapStrings;
  inherit (config.device) gpu;
  cfg = config.modules.services.lact;

  # I haven't worked out why yet but sometimes my GPU's PCIE address changes,
  # causing the LACT config to not load. It only seems to switch between these
  # two IDs though so I can workaround it by adding the same config for each
  # ID.
  gpuIds = [
    "1002:744C-1EAE:7905-0000:08:00.0"
    "1002:744C-1EAE:7905-0000:09:00.0"
  ];
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

    # Master branch fixes power profile modifications
    package = pkgs.lact.overrideAttrs (oldAttrs: rec {
      version = "git";
      src = pkgs.fetchFromGitHub {
        owner = "ilya-zlobintsev";
        repo = "LACT";
        rev = "4db593c73f7b46a8d1466bf5734e9a764c43afb7";
        hash = "sha256-ehJYUZ4Bdttqzs3/SSvhJRzPO7CPbeP8ormXQ7NUzXI=";
      };
      cargoDeps = oldAttrs.cargoDeps.overrideAttrs (_: {
        inherit src;
        outputHash = "sha256-SX+2u0VbMPQTPxHwikmpaRgZ+y5Tp7Splogb6hJdpxo=";
      });
    });

    # Can't use nix yaml because the keys for fan curve have to be integers
    settings =
      let
        gpuConfig = /*yaml*/ ''
          fan_control_enabled: true
          fan_control_settings:
            mode: curve
            static_speed: 0.5
            temperature_key: edge
            interval_ms: 500
            curve:
              60: 0.0
              70: 0.5
              75: 0.6
              80: 0.65
              90: 1
          pmfw_options:
            acoustic_limit: 3300
            acoustic_target: 2000
            minimum_pwm: 15
            target_temperature: 80
          # Run at 257 for slightly better performance but louder fans
          power_cap: 231.0
          performance_level: manual
          max_core_clock: 2394
          voltage_offset: -30
          power_profile_mode_index: 0
          power_states:
            memory_clock:
            - 0
            - 1
            - 2
            - 3
            core_clock:
            - 0
            - 1
            - 2
        '';
      in
        /*yaml*/ ''
        daemon:
          log_level: info
          admin_groups:
          - wheel
          - sudo
          disable_clocks_cleanup: false
        apply_settings_timer: 5
        gpus:
        ${
          concatMapStrings (gpuId: ''
            # anchor for correct indendation
              ${gpuId}:
                ${lib.replaceStrings ["\n" ] ["\n    "] gpuConfig}
          '') gpuIds
        }
      '';
  };

  # Set LACT_HIGH_PERF=1 when using gamemoderun for higher power cap of 257. In
  # unigine superposition 4k optimised gives an 8% FPS instead (132fps ->
  # 122fps). Max core clock speeds go 2000MHz -> 2200Mhz. Thermals are a fair
  # bit worse though, ~200rpm fan increase.

  # TODO: Since gamemoderun does not allow passing custom args or env vars to
  # the start/stop scripts, I'll need to wrap it to enable conditional GPU
  # modes.
  modules.programs.gaming.gamemode =
    let
      ncat = getExe' pkgs.nmap "ncat";
      jaq = getExe pkgs.jaq;
      confirm = ''echo '{"command": "confirm_pending_config", "args": {"command": "confirm"}}' | ${ncat} -U /run/lactd.sock'';
      getId = ''echo '{"command": "list_devices"}' | ${ncat} -U /run/lactd.sock | ${jaq} -r ".data.[0].id"'';

      setPowerCap = powerCap: /*bash*/ ''
        echo "{\"command\": \"set_power_cap\", \"args\": {\"id\": \"$id\", \"cap\": ${toString powerCap}}}" | ${ncat} -U /run/lactd.sock
        ${confirm}
      '';

      setPowerProfile = profileIndex: /*bash*/ ''
        echo "{\"command\": \"set_power_profile_mode\", \"args\": {\"id\": \"$id\", \"index\": ${toString profileIndex}}}" | ${ncat} -U /run/lactd.sock
        ${confirm}
      '';
    in
    {
      startScript = ''
        id=$(${getId})
        ${setPowerProfile 1}
        # if [ -n "''${LACT_HIGH_PERF+x}" ]; then
        #   ${setPowerCap 257}
        # fi
      '';

      stopScript = ''
        id=$(${getId})
        ${setPowerProfile 0}
        # ${setPowerCap 231}
      '';
    };
}
