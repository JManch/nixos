{ config
, inputs
, pkgs
, lib
, ...
}:
let
  cfg = config.modules.programs.discord;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    discord
    vesktop
  ];

  programs.firefox.package = pkgs.firefox.override {
    nativeMessagingHosts = [
      inputs.pipewire-screenaudio.packages.${pkgs.system}.default
    ];
  };

  impermanence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
