{ lib
, config
, ...
}:
let
  cfg = config.modules.programs.btop;
  colors = config.colorscheme.palette;
in
lib.mkIf cfg.enable {

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "custom";
    };

  };

  xdg.configFile."btop/themes/custom.theme".text = ''
    theme[main_bg]="#${colors.base00}"
    theme[main_fg]="#${colors.base05}"
    theme[title]="#${colors.base06}"
    theme[hi_fg]="#${colors.base0A}"
    theme[selected_bg]="#${colors.base02}"
    theme[selected_fg]="#${colors.base07}"
    theme[inactive_fg]="#${colors.base04}"
    theme[graph_text]="#${colors.base06}"
    theme[meter_bg]="#${colors.base03}"
    theme[proc_misc]="#${colors.base0E}"
    theme[cpu_box]="#${colors.base0E}"
    theme[mem_box]="#${colors.base0C}"
    theme[net_box]="#${colors.base08}"
    theme[proc_box]="#${colors.base0A}"
    theme[div_line]="#${colors.base04}"
    theme[temp_start]="#${colors.base0E}"
    theme[temp_mid]="#${colors.base0A}"
    theme[temp_end]="#${colors.base09}"
    theme[cpu_start]="${colors.base0E}"
    theme[cpu_mid]="${colors.base0A}"
    theme[cpu_end]="${colors.base09}"
    theme[free_start]="#${colors.base0C}"
    theme[free_mid]="#${colors.base0C}"
    theme[free_end]="#${colors.base0D}"
    theme[cached_start]="#${colors.base0C}"
    theme[cached_mid]="#${colors.base0C}"
    theme[cached_end]="#${colors.base0D}"
    theme[available_start]="#${colors.base0C}"
    theme[available_mid]="#${colors.base0C}"
    theme[available_end]="#${colors.base0D}"
    theme[used_start]="#${colors.base0C}"
    theme[used_mid]="#${colors.base0C}"
    theme[used_end]="#${colors.base0D}"
    theme[download_start]="#${colors.base09}"
    theme[download_mid]="#${colors.base09}"
    theme[download_end]="#${colors.base08}"
    theme[upload_start]="#${colors.base0C}"
    theme[upload_mid]="#${colors.base0C}"
    theme[upload_end]="#${colors.base0D}"
    theme[process_start]="#${colors.base0A}"
    theme[process_mid]="#${colors.base0A}"
    theme[process_end]="#${colors.base09}"
  '';

  xdg.desktopEntries."btop" = {
    name = "btop";
    genericName = "Resource Monitor";
    exec = "${config.programs.alacritty.package}/bin/alacritty --title btop -e ${config.programs.btop.package}/bin/btop";
    terminal = false;
    type = "Application";
    categories = [ "System" ];
  };

}
