{
  lib,
  pkgs,
  args,
  config,
  osConfig,
}:
let
  inherit (lib) ns concatStringsSep optionalString;
  inherit (osConfig.${ns}) persistence;
  inherit (osConfig.${ns}.core) device;

  themePath = "btop/themes/custom.theme";
  package = lib.${ns}.wrapAlacrittyOpaque args (
    pkgs.btop.override {
      cudaSupport = device.gpu.type == "nvidia";
      rocmSupport = device.gpu.type == "amd";
    }
  );
in
{
  home.packages = [ package ];

  xdg.configFile."btop/btop.conf".text = ''
    color_theme = "custom"
    custom_gpu_name0 = "${device.gpu.name}"
    show_gpu_info = "off"
    shown_boxes = "cpu mem net proc gpu0"
    vim_keys = True
    ${optionalString persistence.enable ''
      disks_filter = "exclude=${
        concatStringsSep " " (
          map (p: p.filePath) persistence.files ++ map (p: p.dirPath) persistence.directories
        )
      }"
    ''}
  '';

  xdg.configFile.${themePath}.text = with config.colorScheme.palette; ''
    theme[main_bg]="#${base00}"
    theme[main_fg]="#${base05}"
    theme[title]="#${base06}"
    theme[hi_fg]="#${base0A}"
    theme[selected_bg]="#${base02}"
    theme[selected_fg]="#${base07}"
    theme[inactive_fg]="#${base04}"
    theme[graph_text]="#${base06}"
    theme[meter_bg]="#${base03}"
    theme[proc_misc]="#${base0E}"
    theme[cpu_box]="#${base0E}"
    theme[mem_box]="#${base0C}"
    theme[net_box]="#${base08}"
    theme[proc_box]="#${base0A}"
    theme[div_line]="#${base04}"
    theme[temp_start]="#${base0E}"
    theme[temp_mid]="#${base0A}"
    theme[temp_end]="#${base09}"
    theme[cpu_start]="${base0E}"
    theme[cpu_mid]="${base0A}"
    theme[cpu_end]="${base09}"
    theme[free_start]="#${base0C}"
    theme[free_mid]="#${base0C}"
    theme[free_end]="#${base0D}"
    theme[cached_start]="#${base0C}"
    theme[cached_mid]="#${base0C}"
    theme[cached_end]="#${base0D}"
    theme[available_start]="#${base0C}"
    theme[available_mid]="#${base0C}"
    theme[available_end]="#${base0D}"
    theme[used_start]="#${base0C}"
    theme[used_mid]="#${base0C}"
    theme[used_end]="#${base0D}"
    theme[download_start]="#${base09}"
    theme[download_mid]="#${base09}"
    theme[download_end]="#${base08}"
    theme[upload_start]="#${base0C}"
    theme[upload_mid]="#${base0C}"
    theme[upload_end]="#${base0D}"
    theme[process_start]="#${base0A}"
    theme[process_mid]="#${base0A}"
    theme[process_end]="#${base09}"
  '';

  ns.desktop.darkman.switchApps.btop = {
    paths = [ ".config/${themePath}" ];
  };
}
