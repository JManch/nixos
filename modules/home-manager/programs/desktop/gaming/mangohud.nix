{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkOption
    assertMsg
    types
    optionalString
    stringLength
    toUpper
    ;
  inherit (config.colorScheme) palette;
  device = osConfig.${ns}.core.device or null;
  shiftR = if cfg.noShiftR then "Shift_L" else "Shift_R";

  mkDeviceNameOption =
    type:
    mkOption {
      type = types.str;
      default = device.${type}.name;
      apply =
        name:
        assert (
          assertMsg (
            stringLength name <= 10
          ) "MangoHud ${toUpper type} name '${name}' length must be <= 10 chars otherwise it overlaps"
        );
        name;
    };
in
{
  opts = {
    cpuName = mkDeviceNameOption "cpu";
    gpuName = mkDeviceNameOption "gpu";

    fontSize = mkOption {
      type = types.int;
      default = 24;
      description = ''
        Font size affects the width and height of the overlay. May need to be
        tweaked depending on whether the host uses scaling.
      '';
    };

    noShiftR = mkOption {
      type = types.bool;
      default = osConfig.${ns}.hardware.keyd.hhkbArrowLayer;
      description = ''
        Whether to only use Shift_L binds instead of Shift_R. Useful on hosts
        where Shift_R doesn't work if keyd is used for example.
      '';
    };
  };

  home.packages = [ pkgs.mangohud ];

  # Not using home manager module because the ordering of elements in the
  # interface depends on config order and the module gives no control over
  # ordering.
  xdg.configFile."MangoHud/MangoHud.conf".text = # ini
    ''
      legacy_layout=0
      no_display # hide the HUD by default
      font_size=${toString cfg.fontSize}
      hud_compact
      round_corners=${toString config.${ns}.desktop.style.cornerRadius}
      fps_limit=0,60${
        optionalString (
          device.primaryMonitor.refreshRate != 60
        ) ",${toString device.primaryMonitor.refreshRate}"
      }${
        optionalString (
          device.primaryMonitor.gamingRefreshRate != 60
          && device.primaryMonitor.gamingRefreshRate != device.primaryMonitor.refreshRate
        ) ",${toString device.primaryMonitor.gamingRefreshRate}}"
      }

      toggle_fps_limit=Shift_L+F1
      toggle_logging=Shift_L+F2
      reload_cfg=Shift_L+F4
      toggle_preset=${shiftR}+F10
      toggle_hud_position=${shiftR}+F11
      toggle_hud=${shiftR}+F12

      text_color=${palette.base07}
      gpu_color=${palette.base08}
      cpu_color=${palette.base09}
      vram_color=${palette.base0E}
      ram_color=${palette.base0C}
      engine_color=${palette.base0F}
      io_color=${palette.base0D}
      frametime_color=${palette.base0B}
      background_color=${palette.base00}
      cpu_load_color=${palette.base0B},${palette.base0A},${palette.base08}
      gpu_load_color=${palette.base0B},${palette.base0A},${palette.base08}
      fps_color=${palette.base0B},${palette.base0A},${palette.base08}

      cpu_load_change
      cpu_mhz
      cpu_power
      cpu_stats
      cpu_temp
      cpu_text=${cfg.cpuName}

      ram

      gpu_core_clock
      gpu_fan
      gpu_junction_temp
      gpu_load_change
      gpu_mem_clock
      gpu_mem_temp
      gpu_power
      gpu_stats
      gpu_temp
      ${optionalString (device.gpu.type != null) "gpu_text=${cfg.gpuName}"}
      gpu_voltage

      vram

      ${optionalString (device.battery != null) ''
        battery
        battery_watt
      ''}

      io_read
      io_write

      fsr
      gamemode
      resolution
      refresh_rate
      vulkan_driver
      histogram

      show_fps_limit
      fps
      frame_timing
      frametime
    '';
}
