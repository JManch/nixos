{
  environment.persistence."/persist" = {
    users.joshua = {
      # Program specific. This is not a nice solution since it means my
      # home-manager config is no longer truly modular. Waiting on a solution
      # maybe here https://redd.it/15xxqlj
      ".cache/nvidia"

      ".mozilla"
      ".cache/mozilla"

      ".cache/starship"

      ".config/nvim"
      ".local/share/nvim"
      ".cache/nvim"

      ".cache/swww"

      ".config/discord"

      ".cache/spotify"
      ".config/spotify"
    };
  };
}
