{
  enableOpt = false;

  programs.tealdeer = {
    enable = true;
    settings.style = {
      command_name.foreground = "red";
      example_variable.foreground = "blue";
      example_text.foreground = "green";
      example_code.foreground = "red";
    };
  };

  nsConfig.persistence.directories = [ ".cache/tealdeer" ];
}
