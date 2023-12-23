{
  programs.winbox = {
    enable = true;
    openFirewall = true;
  };

  environment.persistence."/persist".users.joshua = {
    directories = [
      ".local/share/winbox"
    ];
  };
}
