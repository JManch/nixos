{
  environment.persistence."/persist" = {
    users.joshua = {
      directories = [
        ".cache/starship"

        ".config/nvim"
        ".local/share/nvim"
        ".cache/nvim"

        ".mozilla"
        ".cache/mozilla"
      ];
    };
  };
}
