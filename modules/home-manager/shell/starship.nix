{ lib, config, ... }:
let
  cfg = config.modules.shell;
in
lib.mkIf cfg.enable
{
  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;
      format = "$directory$character";
      right_format = "$all";
      memory_usage.disabled = true;

      character = {
        success_symbol = "[❯](${cfg.promptColor})";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](${cfg.promptColor})";
        vimcmd_replace_one_symbol = "[❮](purple)";
        vimcmd_replace_symbol = "[❮](purple)";
        vimcmd_visual_symbol = "[❮](yellow)";
      };

      hostname = {
        format = "[$hostname]($style)";
        style = "white";
      };

      username = {
        format = "[$user@]($style)";
        style_user = "white";
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
    };
  };

  persistence.directories = [ ".cache/starship" ];
}
