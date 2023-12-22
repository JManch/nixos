{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$character";
      right_format = "$all";
      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
        vimcmd_replace_one_symbol = "[❮](purple)";
        vimcmd_replace_symbol = "[❮](purple)";
        vimcmd_visual_symbol = "[❮](yellow)";
      };
      hostname = {
        ssh_symbol = "";
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
      memory_usage = {
        disabled = false;
        threshold = 50;
        style = "dimmed white";
      };
    };
  };
}
