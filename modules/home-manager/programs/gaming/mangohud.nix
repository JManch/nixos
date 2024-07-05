{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf utils;
  inherit (osConfig) device;
  inherit (config.modules.desktop.style) cornerRadius;
  cfg = config.modules.programs.gaming.mangohud;
  colors = config.colorScheme.palette;
in
mkIf cfg.enable
{
  # WARN: For some reason mangohud toggle does not work in gamescope with the
  # --mangoapp argument. If mangohud is initially hidden with no_display=true,
  # it never shows. If no_display is not set, mangohud will be displayed until
  # the first toggle, after which it hides and never shows again.
  programs.mangohud = {
    enable = true;
    package = utils.addPatches pkgs.mangohud [ ../../../../patches/mangoHud.diff ];

    settings = {
      # Performance
      fps_limit = "0,60,144,165";
      show_fps_limit = true;

      # UI
      legacy_layout = 0;
      no_display = true; # hide the HUD by default
      font_size = 20;
      round_corners = "${toString cornerRadius}";
      hud_compact = true;
      text_color = colors.base07;
      gpu_color = colors.base08;
      cpu_color = colors.base09;
      vram_color = colors.base0E;
      ram_color = colors.base0C;
      engine_color = colors.base0F;
      io_color = colors.base0D;
      frametime_color = colors.base0B;
      background_color = colors.base00;

      # GPU
      vram = true;
      gpu_stats = true;
      gpu_temp = true;
      gpu_mem_temp = true;
      gpu_junction_temp = true;
      gpu_core_clock = true;
      gpu_mem_clock = true;
      gpu_power = true;
      gpu_text = device.gpu.name;
      gpu_load_change = true;
      gpu_fan = true;
      gpu_voltage = true;
      gpu_load_color = "${colors.base0B},${colors.base0A},${colors.base08}";
      # Throttling stats are misleading with 7900xt
      throttling_status = false;

      # CPU
      cpu_stats = true;
      cpu_temp = true;
      cpu_power = true;
      cpu_text = device.cpu.name;
      cpu_mhz = true;
      cpu_load_change = true;
      cpu_load_color = "${colors.base0B},${colors.base0A},${colors.base08}";

      # IO
      io_read = true;
      io_write = true;

      # System
      ram = true;
      vulkan_driver = true;
      gamemode = true;
      resolution = true;

      # FPS
      fps = true;
      fps_color = "${colors.base0B},${colors.base0A},${colors.base08}";
      frametime = true;
      frame_timing = true;
      histogram = true;

      # Gamescope
      fsr = true;
      refresh_rate = true;

      # Bindings
      toggle_fps_limit = "Shift_L+F1";
      toggle_hud = "Shift_R+F12";
      toggle_preset = "Shift_R+F10";
      toggle_hud_position = "Shift_R+F11";
      toggle_logging = "Shift_L+F2";
      reload_cfg = "Shift_L+F4";
    };
  };
}
