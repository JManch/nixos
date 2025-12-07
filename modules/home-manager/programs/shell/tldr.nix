{
  enableOpt = false;

  programs.tealdeer = {
    enable = true;
    enableAutoUpdates = false;
    settings.style = {
      command_name.foreground = "red";
      example_variable.foreground = "blue";
      example_text.foreground = "green";
      example_code.foreground = "red";
    };
  };

  ns.persistence.directories = [ ".cache/tealdeer" ];
}
