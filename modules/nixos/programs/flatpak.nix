{
  lib,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib) mkIf ns singleton;
  inherit (config.${ns}.core) home-manager;
in
[
  {
    guardType = "first";

    hm = mkIf home-manager.enable {
      services.flatpak = {
        enable = true;
        uninstallUnmanaged = true;

        overrides.global.Context.sockets = [
          "wayland"
          "!x11"
          "!fallback-x11"
        ];

        remotes = singleton {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        };

        update.auto = {
          enable = true;
          onCalendar = "weekly";
        };
      };
    };

    ns.persistence.directories = [ "/var/lib/flatpak" ];
    ns.persistenceHome.directories = [ ".local/share/flatpak" ];

    # We can't enable the nixpkgs module because it has an assertion for
    # config.xdg.portal.enable and we use home-manager for our portal config

    # Copyright (c) 2003-2024 Eelco Dolstra and the Nixpkgs/NixOS contributors
    #
    # Permission is hereby granted, free of charge, to any person obtaining
    # a copy of this software and associated documentation files (the
    # "Software"), to deal in the Software without restriction, including
    # without limitation the rights to use, copy, modify, merge, publish,
    # distribute, sublicense, and/or sell copies of the Software, and to
    # permit persons to whom the Software is furnished to do so, subject to
    # the following conditions:
    #
    # The above copyright notice and this permission notice shall be
    # included in all copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    # LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    # WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    environment.systemPackages = [ pkgs.flatpak ];

    security.polkit.enable = true;

    fonts.fontDir.enable = true;

    services.dbus.packages = [ pkgs.flatpak ];

    systemd.packages = [ pkgs.flatpak ];
    systemd.tmpfiles.packages = [ pkgs.flatpak ];

    environment.profiles = [
      "$HOME/.local/share/flatpak/exports"
      "/var/lib/flatpak/exports"
    ];

    # It has been possible since https://github.com/flatpak/flatpak/releases/tag/1.3.2
    # to build a SELinux policy module.

    # TODO: use sysusers.d
    users.users.flatpak = {
      description = "Flatpak system helper";
      group = "flatpak";
      isSystemUser = true;
    };

    users.groups.flatpak = { };
  }

  { home-manager.sharedModules = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ]; }
]
