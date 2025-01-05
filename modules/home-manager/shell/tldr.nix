{ lib, config, ... }:
lib.mkIf (config.${lib.ns}.shell.enable) {
  programs.tealdeer = {
    enable = true;
    settings.style = {
      command_name.foreground = "red";
      example_variable.foreground = "blue";
      example_text.foreground = "green";
      example_code.foreground = "red";
    };
  };

  persistence.directories = [ ".cache/tealdeer" ];
}
