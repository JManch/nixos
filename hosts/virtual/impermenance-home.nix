{username, ...}: {
  environment.persistence."/persist" = {
    users.${username} = {
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
