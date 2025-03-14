{
  lib,
  pkgs,
  config,
  inputs,
  osConfig,
  selfPkgs,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    singleton
    ;
  inherit (lib.${ns}) isHyprland sliceSuffix;
  inherit (config.${ns}.desktop.hyprland) modKey namedWorkspaceIDs;

  # This script acts as a replacement for Multiviewer's layout saving/loading
  # system which doesn't work with a tiling window manager. The idea is that
  # Multiviewer layouts are still used to load all the windows. The windows get
  # dumped onto the F1 workspace then I press a keybind to run this script and
  # position the windows.

  # The script uses the Multiviewer's graphql api to order driver windows based
  # on their current position in the race.
  hyprlandMultiviewerTiler =
    pkgs.writers.writePython3 "hyprland-multiviewer-tiler"
      {
        libraries =
          (with pkgs.python3Packages; [
            gql
            aiohttp
          ])
          ++ [ selfPkgs.hyprpy ];
      }
      # python
      ''
        import re
        import math
        import time
        from hyprpy import Hyprland
        from gql import gql, Client
        from gql.transport.aiohttp import AIOHTTPTransport

        instance = Hyprland()
        transport = AIOHTTPTransport(url="http://localhost:10101/api/graphql")
        client = Client(transport=transport, fetch_schema_from_transport=False)
        query = gql(
            """
            query Query {
              f1LiveTimingState {
                TimingAppData
              }
            }
        """
        )

        driver_numbers = {
            "Max Verstappen": 1,
            "Franco Colapinto": 43,
            "Lando Norris": 4,
            "Pierre Gasly": 10,
            "Sergio Perez": 11,
            "Fernando Alonso": 14,
            "Charles Leclerc": 16,
            "Lance Stroll": 18,
            "Oliver Bearman": 50,
            "Yuki Tsunoda": 22,
            "Alex Albon": 23,
            "Guanyu Zhou": 24,
            "Nico Hulkenberg": 27,
            "Esteban Ocon": 31,
            "Lewis Hamilton": 44,
            "Carlos Sainz": 55,
            "George Russell": 63,
            "Valtteri Bottas": 77,
            "Oscar Piastri": 81,
            "Liam Lawson": 30,
        }


        def get_monitors():
            global monitors
            _monitors = instance.get_monitors()
            monitors = list()

            for monitor in _monitors:
                if monitor.is_focused:
                    monitors.append(monitor)
                    _monitors.remove(monitor)

            _monitors.sort(key=lambda m: m.position_x)

            left_side = True
            while len(_monitors) > 0:
                if left_side:
                    for i, m in enumerate(_monitors):
                        if (m.position_x >= monitors[0].position_x
                                or i == len(_monitors)):
                            monitors.append(m)
                            _monitors.remove(m)
                else:
                    for i, m in enumerate(reversed(_monitors)):
                        if m.position_x <= monitors[0].position_x or i == 0:
                            monitors.append(m)
                            _monitors.remove(m)
                left_side = not left_side


        class Tile:
            tile_factor = 4

            def __init__(self, number):
                relative_tile = (number - 1) % (Tile.tile_factor**2) + 1
                monitor = monitors[math.ceil(number / (Tile.tile_factor**2)) - 1]
                row = (relative_tile - 1) % Tile.tile_factor + 1
                col = math.ceil(relative_tile / Tile.tile_factor)

                if (monitor.id != monitors[0].id
                        and monitor.position_x < monitors[0].position_x):
                    col = 4 - (col - 1)

                self.number = number
                self.posX = round(
                    monitor.position_x + (col - 1) * (monitor.width / Tile.tile_factor)
                )
                self.posY = round(
                    monitor.position_y + (row - 1) *
                    (monitor.height / Tile.tile_factor)
                )
                self.width = round(monitor.width / Tile.tile_factor)
                self.height = round(monitor.height / Tile.tile_factor)

            def __eq__(self, other):
                return (
                    self.posX == other.posX
                    and self.posY == other.posY
                    and self.width == other.width
                    and self.height == other.height
                )


        class Window:
            def __init__(self, window, tiles):
                self.window = window
                self.tlTile = tiles[0]
                if len(tiles) > 1:
                    self.brTile = tiles[1]
                else:
                    self.brTile = None
                self.dispatch_transform()

            def dispatch_transform(self):
                height = self.tlTile.height
                width = self.tlTile.width

                if self.brTile is not None:
                    height = (self.brTile.posY - self.tlTile.posY) + self.brTile.height
                    width = self.brTile.posX - self.tlTile.posX + self.brTile.width

                instance.dispatch(
                    ["movetoworkspacesilent", f"${namedWorkspaceIDs.F1}, address:{self.window.address}"]
                )
                instance.dispatch(
                    [
                        "movewindowpixel",
                        f"exact {self.tlTile.posX} {self.tlTile.posY},"
                        f"address:{self.window.address}",
                    ]
                )
                instance.dispatch(
                    [
                        "resizewindowpixel",
                        f"exact {width} {height}, address:{self.window.address}",
                    ]
                )

            def place_on_tiles(self, tiles):
                self.tlTile = tiles[0]
                if tiles[1] is not None:
                    self.brTile = tiles[1]
                self.dispatch_transform()


        class DriverCam(Window):
            _driver_cams = dict()

            def __init__(self, window, driver_name):
                self.driver_name = driver_name
                self.number = driver_numbers[driver_name]
                self.window = window
                self.position = len(DriverCam._driver_cams) + 1
                super().__init__(
                    window, (DriverCam.index_to_driver_tile(self.position),)
                )
                DriverCam._driver_cams[driver_name] = self

            def __lt__(self, other):
                return self.position < other.position

            @staticmethod
            def update_driver_positions(positions):
                driver_cams = DriverCam.get_driver_cams()
                for driver_cam in driver_cams:
                    driver_num = str(driver_numbers[driver_cam.driver_name])
                    if driver_num not in positions:
                        print(f"{driver_num} is not a valid driver number")
                        exit(1)
                    driver_cam.position = positions[driver_num]["Line"]

                s_driver_cams = sorted(driver_cams, key=lambda d: d.position)
                for i, driver_cam in enumerate(s_driver_cams, start=1):
                    newTile = DriverCam.index_to_driver_tile(i)
                    if newTile != driver_cam.tlTile:
                        driver_cam.tlTile = newTile
                        driver_cam.dispatch_transform()

            @staticmethod
            def get_driver_cams(windows=None):
                if windows is None:
                    windows = instance.get_windows()

                found_drivers = dict()
                for window in windows:
                    if window.wm_class != "MultiViewer for F1":
                        continue
                    match = re.search(r"^([^—]+)", window.title)
                    if match:
                        name = match.group(1).strip()
                        if name in driver_numbers:
                            found_drivers[name] = True
                            if name not in DriverCam._driver_cams:
                                DriverCam(window, name)

                old_drivers = list()
                for driver_cam in DriverCam._driver_cams.values():
                    if driver_cam.driver_name not in found_drivers:
                        old_drivers.append(driver_cam.driver_name)

                for driver in old_drivers:
                    del DriverCam._driver_cams[driver]

                return DriverCam._driver_cams.values()

            @staticmethod
            def index_to_driver_tile(index):
                tile = 13 + index
                if index <= 3:
                    tile = 4 * (index + 1)
                return Tile(tile)


        def update_driver_window_positions():
            try:
                timingData = client.execute(query)
            except Exception:
                print("Multiviewer is not running. Exiting...")
                exit(0)
            DriverCam.update_driver_positions(
                timingData["f1LiveTimingState"]["TimingAppData"]["Lines"]
            )


        def place_windows():
            windows = instance.get_windows()
            for window in windows:
                title = window.title
                if window.wm_class != "MultiViewer for F1":
                    continue
                elif re.match(r"20|MultiViewer|Home", title):
                    continue
                elif re.match(r"(Replay )?Live Timing", title):
                    Window(window, (Tile(1), Tile(3)))
                elif re.match(r"F1 Live", title):
                    Window(window, (Tile(5), Tile(15)))
                elif re.match(r"Radio Transcriptions|Race Control Messages", title):
                    Window(window, (Tile(4),))
                elif re.match(r"Track Map", title):
                    Window(window, (Tile(15),))
                    instance.dispatch(
                        [
                            "alterzorder",
                            f"top,address:{window.address}",
                        ]
                    )
            DriverCam.get_driver_cams(windows)


        if __name__ == "__main__":
            get_monitors()
            place_windows()
            while True:
                time.sleep(5)
                update_driver_window_positions()
      '';
in
{
  # How to sign in:
  # Launch multiviewer with `multiviewer-for-f1 --no-sandbox` then select the
  # "sign in with multiviewer" option. Future launches do not need the
  # --no-sandbox flag. Signing in with the extension through Chromium doesn't
  # work currently but leaving the Chromium wrapper here in-case it eventually
  # does.
  home.packages = singleton (
    inputs.xdg-override.lib.wrapPackage {
      nameMatch = singleton {
        case = "^https?://";
        command = getExe pkgs.chromium;
      };
    } selfPkgs.multiviewer-for-f1
  );

  ns.desktop = {
    services.waybar.autoHideWorkspaces = [ "F1" ];
    hyprland.namedWorkspaces.F1 = "decorate:false, rounding:false, border:false";

    hyprland.settings = {
      bind = [
        "${modKey}, F, workspace, ${namedWorkspaceIDs.F1}"
        "${modKey}SHIFT, F, movetoworkspace, ${namedWorkspaceIDs.F1}"
        "${modKey}SHIFTCONTROL, F, exec, systemctl restart --user hyprland-multiviewer-tiler"
      ];

      windowrulev2 = [
        "float, class:^(MultiViewer for F1)$"
        "workspace ${namedWorkspaceIDs.F1}, class:^(MultiViewer for F1)$"

        "prop xray 0, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
        "prop noblur, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
        "prop noborder, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
      ];
    };
  };

  ns.persistence.directories = [ ".config/MultiViewer for F1" ];

  systemd.user.services.hyprland-multiviewer-tiler = mkIf (isHyprland config) {
    Unit = {
      Description = "Hyprland Multiviewer F1 Tiler";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "app${sliceSuffix osConfig}.slice";
      Environment = [ "PYTHONUNBUFFERED=1" ];
      ExecStart = hyprlandMultiviewerTiler;
      ExecStopPost = pkgs.writeShellScript "hyprland-multiviewer-tiling-exec-stop-post" ''
        if [ "$SERVICE_RESULT" != "success" ]; then
          ${getExe pkgs.libnotify} --urgency=critical -t 5000 "Multiviewer F1 Tiler" "Exited unexpectedly"
        fi
      '';
    };
  };
}
