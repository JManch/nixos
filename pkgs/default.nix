{ pkgs }:
let
  inherit (pkgs) callPackage;
in
{
  modernx = callPackage ./modernx.nix { };
  filen-desktop = callPackage ./filen-desktop.nix { };
  ctrld = callPackage ./ctrld.nix { };
  frigate-hass-card = callPackage ./frigate-hass-card.nix { };
  frigate-blueprint = callPackage ./frigate-blueprint.nix { };
  shoutrrr = callPackage ./shoutrrr.nix { };
  thermal-comfort = callPackage ./thermal-comfort.nix { };
  thermal-comfort-icons = callPackage ./thermal-comfort-icons.nix { };
  beammp-server = callPackage ./beammp-server { };
  heatmiser = pkgs.home-assistant.python.pkgs.callPackage ./heatmiser.nix { };
  vesktop = callPackage ./vesktop.nix { };
}
