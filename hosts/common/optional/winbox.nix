{username, ...}: {
  programs.winbox = {
    enable = true;
    openFirewall = true;
  };

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".local/share/winbox"
    ];
  };
}
