{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf take fetchers getExe listToAttrs;
  inherit (osConfig.device) monitors;
  cfg = config.modules.programs.multiviewerF1;
  desktopCfg = config.modules.desktop;

  multiviewer-for-f1 =
    pkgs.multiviewer-for-f1.overrideAttrs (_: rec {
      version = "1.31.10";

      src = pkgs.fetchurl {
        url = "https://releases.multiviewer.app/download/167189307/multiviewer-for-f1_${version}_amd64.deb";
        sha256 = "sha256-bWxzAX+HoPTfhaQKCbJZ5Btz17ZzpnFA1/PxIx1F9BU=";
      };

      # Add libglvnd to library path for hardware acceleration
      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/share
        mv -t $out/share usr/share/* usr/lib/multiviewer-for-f1

        makeWrapper "$out/share/multiviewer-for-f1/MultiViewer for F1" $out/bin/multiviewer-for-f1 \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations}}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libudev0-shim pkgs.libglvnd ]}:\"$out/share/Multiviewer for F1\""

        runHook postInstall
      '';
    });

  # This script acts as a replacement for the Multiviewer layout saving which
  # doesn't work with a tiling window manager. The idea is that Multiviewer
  # layouts are still used to load all the windows. This windows get stacked in
  # a pile on the F1 workspace. Then I press a keybind to activate this script
  # which positions all the windows where I want across two monitors.
  multiviewerWorkspaceScript =
    let
      inherit (lib) remove head last optionalString;
      monitor1 = fetchers.getMonitorByNumber osConfig 1;
      monitor2 = fetchers.getMonitorByNumber osConfig 2;
      monitor1Positions = remove [ ] (builtins.split "x" monitor1.position);
      monitor2Positions = remove [ ] (builtins.split "x" monitor2.position);
    in
    pkgs.writeShellApplication {
      name = "hypr-multiviewer-workspace";

      runtimeInputs = with pkgs; [
        config.wayland.windowManager.hyprland.package
        jaq
      ];

      # Only generate script if two monitors exist
      text = optionalString (monitor1.number != monitor2.number) /*bash*/ ''

        m1_pos_x=${head monitor1Positions}
        m1_pos_y=${last monitor1Positions}
        m1_res_x=${toString monitor1.width}
        m1_res_y=${toString monitor1.height}
        m2_pos_x=${head monitor2Positions}
        m2_pos_y=${last monitor2Positions}
        m2_res_x=${toString monitor2.width}
        m2_res_y=${toString monitor2.height}

        # Get window address and title of all F1 windows
        windows=$(hyprctl clients -j | jaq -r '((.[] | select((.workspace.name | test("F1-(\\d+)")) and (.class == "MultiViewer for F1") )) | "\(.address),\(.title)")')

        hyprctl_cmd="hyprctl --batch \""
        declare -a drivers
        declare -A driver_prio

        driver_prio["Esteban Ocon"]=20
        driver_prio["Pierre Gasly"]=20
        driver_prio["Fernando Alonso"]=2
        driver_prio["Lance Stroll"]=20
        driver_prio["Carlos Sainz"]=4
        driver_prio["Charles Leclerc"]=3
        driver_prio["Kevin Magnussen"]=20
        driver_prio["Nico Hulkenberg"]=20
        driver_prio["Guanyu Zhou"]=20
        driver_prio["Valtteri Bottas"]=20
        driver_prio["Lando Norris"]=6
        driver_prio["Oscar Piastri"]=5
        driver_prio["George Russell"]=20
        driver_prio["Lewis Hamilton"]=20
        driver_prio["Daniel Ricciardo"]=20
        driver_prio["Yuki Tsunoda"]=20
        driver_prio["Max Verstappen"]=1
        driver_prio["Sergio Perez"]=20
        driver_prio["Alexander Albon"]=20
        driver_prio["Logan Sergeant"]=20

        while IFS=, read -r address title; do
          case $title in
            "Live Timing"*|"Replay Live Timing"*)
              res_x=$((m1_res_x * 1 / 4))
              res_y=$((m1_res_y * 3 / 4))
              hyprctl_cmd+="dispatch movetoworkspacesilent name:F1-1,address:$address;"
              hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
              hyprctl_cmd+="dispatch movewindowpixel exact $m1_pos_x $m1_pos_y,address:$address;"
              ;;
            "F1 Live"*)
              res_x=$((m1_res_x * 3 / 4))
              res_y=$((m1_res_y * 3 / 4))
              hyprctl_cmd+="dispatch movetoworkspacesilent name:F1-1,address:$address;"
              hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
              hyprctl_cmd+="dispatch movewindowpixel exact $((m1_pos_x + (m1_res_x - res_x))) $m1_pos_y,address:$address;"
              hyprctl_cmd+="dispatch alterzorder bottom,address:$address;"
              ;;
            "Track Map"*)
              res_x="480"
              res_y="300"
              hyprctl_cmd+="dispatch movetoworkspacesilent name:F1-1,address:$address;"
              hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
              hyprctl_cmd+="dispatch movewindowpixel exact $((m1_pos_x + m1_res_x - res_x)) $((m1_pos_y + (m1_res_y * 3 / 4) - (res_y + 60))),address:$address;"
              hyprctl_cmd+="dispatch alterzorder top,address:$address;"
              hyprctl_cmd+="dispatch pin address:$address;"
              ;;
            "Radio Transcriptions"*|"Race Control"*)
              res_x=$((m1_res_x * 1 / 4))
              res_y=$((m1_res_y * 1 / 4))
              hyprctl_cmd+="dispatch movetoworkspacesilent name:F1-1,address:$address;"
              hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
              hyprctl_cmd+="dispatch movewindowpixel exact $m1_pos_x $((m1_pos_y + (m1_res_y * 3 / 4))),address:$address;"
              ;;
            *)
              # Assume it's a driver cam
              regex="^([^—]+)"
              if [[ $title =~ $regex ]]; then
                driver=''${BASH_REMATCH[1]}
                driver="''${driver%?}"
                if [[ -v driver_prio["$driver"] ]]; then
                  drivers+=("''${driver_prio["$driver"]},$address")
                else
                  # Reserve drivers
                  drivers+=("100,$address")
                fi
              fi
              ;;
          esac
        done <<< "$windows"

        # Sort the driver windows according to priority
        sorted_drivers=$(printf "%s\n" "''${drivers[@]}" | sort -n -t ',' -k 1)

        # Iterate through sorted driver windows and place in a grid-style layout
        counter=0
        while IFS=, read -r _ address; do
          res_x=$((m2_res_x * 1 / 4))
          res_y=$((m2_res_y * 1 / 4))

          # First 3 drivers go on primary monitor and rest go on secondary
          if [[ "$counter" -lt 3 ]]; then
            hyprctl_cmd+="dispatch movetoworkspacesilent name:F1-1,address:$address;"
            hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
            hyprctl_cmd+="dispatch movewindowpixel exact $((m1_pos_x + (counter + 1) * res_x)) $((m1_pos_y + (m1_res_y * 3 / 4))),address:$address;"
          else
            column=$(((counter-3) / 4))
            row=$(((counter-3) % 4))
            pos_x=$((m2_pos_x + (3 - column) * res_x))
            pos_y=$((m2_pos_y + row * res_y))
            hyprctl_cmd+="dispatch movetoworkspacesilent name:F1-2,address:$address;"
            hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
            hyprctl_cmd+="dispatch movewindowpixel exact $pos_x $pos_y,address:$address;"
          fi
          ((++counter))
        done <<< "$sorted_drivers"

        hyprctl_cmd+="\""
        eval "$hyprctl_cmd"

      '';
    };
in
lib.mkIf cfg.enable
{
  home.packages = [ multiviewer-for-f1 ];

  programs.waybar.settings.bar."hyprland/workspaces".format-icons = mkIf (desktopCfg.windowManager == "Hyprland")
    (listToAttrs
      (map (m: { name = "F1-${toString m.number}"; value = "F1"; })
        (take 2 monitors)
      )
    );

  desktop.hyprland.settings =
    let
      inherit (config.modules.desktop.hyprland) modKey;
      inherit (desktopCfg.style) gapSize;
    in
    {
      workspace = (map
        (
          m: "name:F1-${toString m.number}, monitor:${m.name}, gapsin:0, gapsout:0, decorate:false, rounding:false, border:false"
        )
        (take 2 monitors));

      bind = (
        map (m: "${modKey}, F, workspace, name:F1-${toString m.number}")
          (take 2 monitors)
      )
      ++ [
        "${modKey}SHIFTCONTROL, F, exec, ${getExe multiviewerWorkspaceScript}"
        "${modKey}SHIFT, F, movetoworkspace, name:F1-2"
      ];

      windowrulev2 =
        [
          "float, class:^(MultiViewer for F1)$"
          "workspace name:F1-1, class:^(MultiViewer for F1)$"

          "xray 0, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
          "noblur, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
        ];
    };

  persistence.directories = [
    ".config/MultiViewer for F1"
  ];
}
