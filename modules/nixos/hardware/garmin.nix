# Mount garmin with:
# `mkdir -p ~/garmin && jmtpfs ~/garmin`
{ pkgs }:
{
  ns.userPackages = [
    (pkgs.buildFHSEnv {
      name = "garmin-sdkmanager";
      targetPkgs =
        p:
        with p;
        [
          at-spi2-atk
          cairo
          expat
          fontconfig.lib
          freetype
          gdk-pixbuf
          glib
          gtk3
          libgcc.lib
          libjpeg8
          libpng
          libsecret
          libsm
          libx11
          libxext
          libxkbcommon
          libxxf86vm
          pango
          zlib
          curlMinimal
        ]
        ++ (
          with import (fetchTree "github:NixOS/nixpkgs/ac62194c3917d5f474c1a844b6fd6da2db95077d") {
            inherit (pkgs.stdenv.hostPlatform) system;
          }; [
            webkitgtk_4_0
            libsoup_2_4
          ]);

      profile = ''
        # fix blank login screen
        export WEBKIT_DISABLE_COMPOSITING_MODE=1
        # fix glib-networking dep error causing login screen to not load
        export GIO_EXTRA_MODULES="''${GIO_EXTRA_MODULES:+$GIO_EXTRA_MODULES:}${pkgs.glib-networking}/lib/gio/modules"
      '';

      # We expect the garmin sdk toolkit to be unzipped in the cwd
      runScript = "./bin/sdkmanager";
    })
  ];

  # Not using services.udev.extraRules due to https://github.com/NixOS/nixpkgs/issues/308681
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "garmin-udev-rules";
      destination = "/etc/udev/rules.d/70-garmin.rules";
      text = ''
        # Forerunner 165 music
        SUBSYSTEM=="usb", ATTR{idVendor}=="091e", ATTR{idProduct}=="5151", ENV{ID_MTP_DEVICE}="1", TAG+="uaccess"
      '';
    })
  ];
}
