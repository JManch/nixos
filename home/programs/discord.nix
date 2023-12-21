{ pkgs, inputs, lib, ... }:
let
  discord-flags = [
    "--enable-features=UseOzonePlatform"
    "--ozone-platform=wayland"
  ];
in
{
  # https://discourse.nixos.org/t/partly-overriding-a-desktop-entry/20743/2

  # I'm not actually using this because NIXOS_OZONE_WL=1 is sufficient
  home.packages = [
    (pkgs.discord.overrideAttrs (oldAttrs: rec {
      desktopItem = oldAttrs.desktopItem.override {
        exec = "${pkgs.discord}/bin/Discord " + lib.concatStringsSep " " discord-flags;
      };
      installPhase = builtins.replaceStrings ["${oldAttrs.desktopItem}"] ["${desktopItem}"] oldAttrs.installPhase;
    }))
  ];

  home.persistence."/persist/home/joshua".directories = [ ".config/discord" ];
}
