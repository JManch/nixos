self: lib: pkgs:
let
  inherit (pkgs) callPackage;
  sources = import ../npins;
  args = { inherit sources; };
in
{
  # Npins managed
  modernx = callPackage ./modernx.nix args;
  beammp-server = callPackage ./beammp-server args;
  ctrld = callPackage ./ctrld.nix args;
  beammp-launcher = callPackage ./beammp-launcher.nix args;
  hyprpy = pkgs.python3Packages.callPackage ./hyprpy.nix args;
  soularr = pkgs.python3Packages.callPackage ./soularr.nix args;
  app2unit = callPackage ./app2unit.nix args;
  xdg-terminal-exec = callPackage ./xdg-terminal-exec.nix args;
  jellyfin-plugin-listenbrainz = callPackage ./jellyfin-plugin-listenbrainz args;
  filen-cli = callPackage ./filen-cli.nix args;
  frigate-blueprint = callPackage ./frigate-blueprint.nix args;
  thermal-comfort = pkgs.home-assistant.python.pkgs.callPackage ./thermal-comfort.nix args;
  thermal-comfort-icons = callPackage ./thermal-comfort-icons.nix args;
  heatmiser = pkgs.home-assistant.python.pkgs.callPackage ./heatmiser.nix args;
  daikin-onecta = pkgs.home-assistant.python.pkgs.callPackage ./daikin-onecta.nix args;
  formulaone-card = callPackage ./formulaone-card.nix args;
  brightnessctl = callPackage ./brightnessctl.nix args;
  slskd-stats = pkgs.python3Packages.callPackage ./slskd-stats.nix args;

  # Manual
  advanced-camera-card = callPackage ./advanced-camera-card.nix { };
  multiviewer-for-f1 = callPackage ./multiviewer-for-f1.nix { };
  filen-desktop = callPackage ./filen-desktop.nix args;

  # Other
  bootstrap-kit = callPackage ./bootstrap-kit.nix { };
  kobo-dither-cbz = callPackage ./kobo-dither-cbz { };
  microfetch = lib.${lib.ns}.addPatches pkgs.microfetch [ "microfetch-icon.patch" ];
}
// import ./installers.nix lib self
