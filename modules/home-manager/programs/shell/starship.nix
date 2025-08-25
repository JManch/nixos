{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (config.${lib.ns}.programs.shell) promptColor;
  tomlFormat = pkgs.formats.toml { };
in
{
  enableOpt = false;

  opts.settings = lib.mkOption {
    type = tomlFormat.type;
    default = { };
    description = "Starship settings";
  };

  categoryConfig.starship.settings = {
    add_newline = false;
    format = "$directory$character";
    right_format = "$all";
    memory_usage.disabled = true;
    hostname.format = "$hostname ";
    username.format = "$user@";

    character = {
      success_symbol = "[❯](${promptColor})";
      error_symbol = "[❯](red)";
      vimcmd_symbol = "[❮](${promptColor})";
      vimcmd_replace_one_symbol = "[❮](purple)";
      vimcmd_replace_symbol = "[❮](purple)";
      vimcmd_visual_symbol = "[❮](yellow)";
    };

    directory = {
      format = "[$path]($style)[$read_only]($read_only_style) ";
      style = "cyan";
    };

    git_metrics = {
      disabled = false;
      added_style = "green";
      deleted_style = "red";
    };

    git_status = {
      stashed = "";
      ahead = "󱦲";
      behind = "󱦳";
      diverged = "󰹺";
    };
  };

  xdg.configFile."starship.toml".source = tomlFormat.generate "starship-config" cfg.settings;

  home.packages = [ pkgs.starship ];

  programs.zsh.initContent = ''
    if [[ $TERM != "dumb" ]]; then
      eval "$(${lib.getExe pkgs.starship} init zsh)"
    fi
  '';

  ns.persistence.directories = [ ".cache/starship" ];
}
