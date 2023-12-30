{ username
, config
, lib
, ...
}:
lib.mkIf (config.modules.programs.winbox.enable) {
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
