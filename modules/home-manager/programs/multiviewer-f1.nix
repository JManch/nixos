{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf getExe;
  cfg = config.modules.programs.multiviewerF1;

  multiviewer-for-f1 =
    pkgs.multiviewer-for-f1.overrideAttrs (_: rec {
      version = "1.34.0";

      src = pkgs.fetchurl {
        url = "https://releases.multiviewer.app/download/175381293/multiviewer-for-f1_${version}_amd64.deb";
        sha256 = "sha256-8qQWNFmZaPWZD/rg/AFuQ7W0ZZUVxY8WBylR3JhxRi8=";
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
  # layouts are still used to load all the windows. The windows get dumped onto
  # the F1 workspace then I press a keybind to run this script and position the
  # windows.
  multiviewerWorkspaceScript = pkgs.writeShellApplication {
    name = "hypr-multiviewer-workspace";

    runtimeInputs = [
      config.wayland.windowManager.hyprland.package
      pkgs.jaq
    ];

    text = /*bash*/ ''
      active_monitor=$(hyprctl monitors -j | jaq -r 'first(.[] | select(.focused == true))')
      m_name=$(echo "$active_monitor" | jaq -r '.name')
      m_pos_x=$(echo "$active_monitor" | jaq -r '.x')
      m_pos_y=$(echo "$active_monitor" | jaq -r '.y')
      m_res_x=$(echo "$active_monitor" | jaq -r '.width')
      m_res_y=$(echo "$active_monitor" | jaq -r '.height')

      secondary_monitor=$(hyprctl monitors -j | jaq -r "first(.[] | select(.disabled == false and .name != \"$m_name\"))")
      if [ -n "$secondary_monitor" ]; then
        sm=true
        sm_pos_x=$(echo "$secondary_monitor" | jaq -r '.x')
        sm_pos_y=$(echo "$secondary_monitor" | jaq -r '.y')
        sm_res_x=$(echo "$secondary_monitor" | jaq -r '.width')
        sm_res_y=$(echo "$secondary_monitor" | jaq -r '.height')
      else
        sm=false
      fi

      # Get window address and title of all F1 windows
      windows=$(hyprctl clients -j | jaq -r '((.[] | select(.class == "MultiViewer for F1")) | "\(.address),\(.title)")')

      hyprctl_cmd="hyprctl --batch \""
      hyprctl_cmd+="dispatch moveworkspacetomonitor F1 $m_name;"
      active_workspace=$(hyprctl activeworkspace -j | jaq -r '.name')
      if [[ "$active_workspace" != "F1" ]]; then
        hyprctl_cmd+="dispatch workspace name:F1;"
      fi
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
          "20"*|"MultiViewer")
            # Ignore the main multiviewer window
            ;;
          "Live Timing"*|"Replay Live Timing"*)
            res_x=$((m_res_x * 1 / 4))
            res_y=$((m_res_y * 3 / 4))
            hyprctl_cmd+="dispatch movetoworkspacesilent name:F1,address:$address;"
            hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
            hyprctl_cmd+="dispatch movewindowpixel exact $m_pos_x $m_pos_y,address:$address;"
            ;;
          "F1 Live"*)
            res_x=$((m_res_x * 3 / 4))
            res_y=$((m_res_y * 3 / 4))
            hyprctl_cmd+="dispatch movetoworkspacesilent name:F1,address:$address;"
            hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
            hyprctl_cmd+="dispatch movewindowpixel exact $((m_pos_x + (m_res_x - res_x))) $m_pos_y,address:$address;"
            hyprctl_cmd+="dispatch alterzorder bottom,address:$address;"
            ;;
          "Track Map"*)
            res_x="480"
            res_y="300"
            hyprctl_cmd+="dispatch movetoworkspacesilent name:F1,address:$address;"
            hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
            hyprctl_cmd+="dispatch movewindowpixel exact $((m_pos_x + m_res_x - res_x)) $((m_pos_y + (m_res_y * 3 / 4) - (res_y + 60))),address:$address;"
            hyprctl_cmd+="dispatch alterzorder top,address:$address;"
            hyprctl_cmd+="dispatch pin address:$address;"
            ;;
          "Radio Transcriptions"*|"Race Control"*)
            res_x=$((m_res_x * 1 / 4))
            res_y=$((m_res_y * 1 / 4))
            hyprctl_cmd+="dispatch movetoworkspacesilent name:F1,address:$address;"
            hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
            hyprctl_cmd+="dispatch movewindowpixel exact $m_pos_x $((m_pos_y + (m_res_y * 3 / 4))),address:$address;"
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

        # First 3 drivers go on primary monitor and rest overflow onto secondary
        if [ "$counter" -lt 3 ]; then
          res_x=$((m_res_x * 1 / 4))
          res_y=$((m_res_y * 1 / 4))
          hyprctl_cmd+="dispatch movetoworkspacesilent name:F1,address:$address;"
          hyprctl_cmd+="dispatch resizewindowpixel exact $res_x $res_y,address:$address;"
          hyprctl_cmd+="dispatch movewindowpixel exact $((m_pos_x + (counter + 1) * res_x)) $((m_pos_y + (m_res_y * 3 / 4))),address:$address;"
        elif [ "$sm" = true ]; then
          res_x=$((sm_res_x * 1 / 4))
          res_y=$((sm_res_y * 1 / 4))
          column=$(((counter-3) / 4))
          row=$(((counter-3) % 4))
          # Start tiling on left or right depending on relative position of secondary monitor
          if [ "$((sm_pos_x > m_pos_x))" -eq 1 ]; then
              pos_x=$((sm_pos_x + column * res_x))
          else
              pos_x=$((sm_pos_x + (3 - column) * res_x))
          fi
          pos_y=$((sm_pos_y + row * res_y))
          hyprctl_cmd+="dispatch movetoworkspacesilent name:F1,address:$address;"
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
mkIf cfg.enable
{
  home.packages = [ multiviewer-for-f1 ];

  desktop.hyprland.settings =
    let
      inherit (config.modules.desktop.hyprland) modKey;
    in
    {
      workspace = [
        "name:F1, gapsin:0, gapsout:0, decorate:false, rounding:false, border:false"
      ];

      bind = [
        "${modKey}, F, workspace, name:F1"
        "${modKey}SHIFT, F, movetoworkspace, name:F1"
        "${modKey}SHIFTCONTROL, F, exec, ${getExe multiviewerWorkspaceScript}"
      ];

      windowrulev2 = [
        "float, class:^(MultiViewer for F1)$"
        "workspace name:F1, class:^(MultiViewer for F1)$"

        "xray 0, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
        "noblur, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
        "noborder, class:^(MultiViewer for F1)$, title:^(Track Map.*)$"
      ];
    };

  persistence.directories = [
    ".config/MultiViewer for F1"
  ];
}
