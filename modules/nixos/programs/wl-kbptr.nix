{
  lib,
  pkgs,
  sources,
}:
let
  inherit (lib) getExe;
in
{
  enableOpt = false;
  conditions = [ "hmConfig.desktop.programs.wl-kbptr" ];

  # Reading /dev/input needs the input group. A setgid wrapper avoids adding
  # the user to the group which would let any process read keystrokes.
  security.wrappers.wl-kbptr = {
    owner = "root";
    group = "input";
    setgid = true;
    source = getExe (
      pkgs.wl-kbptr.overrideAttrs (old: {
        version = "0-unstable-${sources.wl-kbptr.revision}";
        src = sources.wl-kbptr;
        patches = (old.patches or [ ]) ++ [
          # Reads keys from evdev so the overlay does not take the keyboard
          # focus which closes open popups and menus
          (pkgs.fetchpatch2 {
            url = "https://github.com/moverest/wl-kbptr/commit/f6fed0cf9cc70eb76f469540804c3c7c0269e496.patch";
            hash = "sha256-Ro+Bu22PwTTHaNYd20JAX3WS4rIntkA7trw4244rgv8=";
          })
        ];
      })
    );
  };
}
