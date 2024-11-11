{
  ns,
  lib,
  config,
  ...
}:
let
  cfg = config.${ns}.shell;
in
lib.mkIf cfg.enable {
  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;
      format = "$directory$character";
      right_format = "$all";
      memory_usage.disabled = true;
      hostname.format = "$hostname ";
      username.format = "$user@";
      git_status.stashed = "";

      character = {
        success_symbol = "[❯](${cfg.promptColor})";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](${cfg.promptColor})";
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
    };
  };

  persistence.directories = [ ".cache/starship" ];
}
