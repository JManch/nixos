{
  lib,
  cfg,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    mkOption
    assertMsg
    types
    stringLength
    toUpper
    ;
  inherit (config.colorScheme) palette;
  device = osConfig.${ns}.core.device or null;
  shiftR = if cfg.noShiftR then "Shift_L" else "Shift_R";

  mkDeviceNameOption =
    device:
    mkOption {
      default = device.${device}.name;
      apply =
        name:
        assert (
          assertMsg (
            stringLength name <= 10
          ) "MangoHud ${toUpper device} name '${name}' length must be <= 10 chars otherwise it overlaps"
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
      default = false;
      description = ''
        Whether to only use Shift_L binds instead of Shift_R. Useful on hosts
        where Shift_R doesn't work if keyd is used for example.
      '';
    };
  };

  # WARN: For some reason mangohud toggle does not work in gamescope with the
  # --mangoapp argument. If mangohud is initially hidden with no_display=true,
  # it never shows. If no_display is not set, mangohud will be displayed until
  # the first toggle, after which it hides and never shows again.
  programs.mangohud = {
    enable = true;

    settings = {
      # Performance
      fps_limit = "0,60,144,165";
      show_fps_limit = true;

      # UI
      legacy_layout = 0;
      no_display = true; # hide the HUD by default
      font_size = cfg.fontSize;
      round_corners = "${toString config.${ns}.desktop.style.cornerRadius}";
      hud_compact = true;
      text_color = palette.base07;
      gpu_color = palette.base08;
      cpu_color = palette.base09;
      vram_color = palette.base0E;
      ram_color = palette.base0C;
      engine_color = palette.base0F;
      io_color = palette.base0D;
      frametime_color = palette.base0B;
      background_color = palette.base00;

      # GPU
      vram = true;
      gpu_stats = true;
      gpu_temp = true;
      gpu_mem_temp = true;
      gpu_junction_temp = true;
      gpu_core_clock = true;
      gpu_mem_clock = true;
      gpu_power = true;
      gpu_text = mkIf (device != null && device.gpu.type != null) cfg.gpuName;
      gpu_load_change = true;
      gpu_fan = true;
      gpu_voltage = true;
      gpu_load_color = "${palette.base0B},${palette.base0A},${palette.base08}";
      # Throttling stats are misleading with 7900xt
      throttling_status = false;

      # CPU
      cpu_stats = true;
      cpu_temp = true;
      cpu_power = true;
      cpu_text = mkIf (device != null) cfg.cpuName;
      cpu_mhz = true;
      cpu_load_change = true;
      cpu_load_color = "${palette.base0B},${palette.base0A},${palette.base08}";

      # IO
      io_read = true;
      io_write = true;

      # System
      ram = true;
      vulkan_driver = true;
      gamemode = true;
      resolution = true;
      battery = mkIf (device.battery != null) true;
      battery_watt = mkIf (device.battery != null) true;

      # FPS
      fps = true;
      fps_color = "${palette.base0B},${palette.base0A},${palette.base08}";
      frametime = true;
      frame_timing = true;
      histogram = true;

      # Gamescope
      fsr = true;
      refresh_rate = true;

      # Bindings
      toggle_fps_limit = "Shift_L+F1";
      toggle_logging = "Shift_L+F2";
      reload_cfg = "Shift_L+F4";
      toggle_preset = "${shiftR}+F10";
      toggle_hud_position = "${shiftR}+F11";
      toggle_hud = "${shiftR}+F12";
    };
  };
}
