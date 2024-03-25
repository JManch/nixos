{ pkgs ? import <nixpkgs> { } }:
{
  pomo = pkgs.callPackage ./pomo.nix { };
  modernx = pkgs.callPackage ./modernx.nix { };
  filen-desktop = pkgs.callPackage ./filen-desktop.nix { };
  ctrld = pkgs.callPackage ./ctrld.nix { };
  frigate-hass-card = pkgs.callPackage ./frigate-hass-card.nix { };
  home-assistant-custom-components = {
    frigate-hass-integration = pkgs.callPackage ./home-assistant-custom-components/frigate-hass-integration.nix { };
  };
}
