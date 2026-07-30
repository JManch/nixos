{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
  vmVariant,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    getExe'
    optionalString
    ;
  inherit (lib.${ns}) throttleHyprlandRepeatBind;
  inherit (config.${ns}) desktop;
  inherit (osConfig.${ns}.core) device;

  notifySend = getExe pkgs.libnotify;

  freezeUnit =
    assert osConfig.${ns}.system.desktop.uwsm.enable;
    pkgs.writeShellScript "hypr-toggle-freeze" # bash
      ''
        pid="$1"

        if [[ ! -f /proc/$pid/cgroup ]]; then
          ${notifySend} --transient --urgency=critical -t 5000 "Freeze" "Unit does not have a cgroup"
          exit 1
        fi

        unit=$(basename "$(<"/proc/$pid/cgroup")")

        if [[ $unit != "app-"* ]]; then
          ${notifySend} --transient --urgency=critical -t 5000 "$unit" "Unit is not app so cannot freeze"
          exit 1
        fi

        if [[ "$(systemctl show --user --property=FreezerState --value "$unit")" == "frozen" ]]; then
          systemctl thaw --user "$unit"
          ${notifySend} --transient --urgency=critical -t 5000 "$unit" "Thawed"
        else
          systemctl freeze --user "$unit"
          ${notifySend} --transient --urgency=critical -t 5000 "$unit" "Frozen"
        fi
      '';

  # By design, the wayland clipboard does not sync with unfocused x clients.
  # It's possible to workaround this but constantly syncing the X clipboard but
  # in my experience the workaround is quite buggy and breaks basic clipboard
  # functionality. Since I don't paste into wine applications very frequently,
  # having a bind to manually sync is an acceptable workaround.
  # https://github.com/hyprwm/Hyprland/issues/2319
  syncClipboard =
    pkgs.writeShellScript "hypr-sync-clipboard" # bash
      ''
        set -o pipefail
        echo -n "$(${getExe' pkgs.wl-clipboard "wl-paste"} -n)" | ${getExe pkgs.xclip} -selection clipboard && \
          ${notifySend} --transient --urgency=low -t 2000 'Hyprland' 'Synced Wayland clipboard with X11' || \
          ${notifySend} --transient --urgency=critical -t 2000 'Hyprland' 'Clipboard sync failed'
      '';

  copyScreenshotText = pkgs.writeShellScript "hypr-copy-screenshot-text" ''
    set -o pipefail
    text=$(${takeScreenshot} copy area - | ${getExe pkgs.tesseract} stdin stdout)
    exit=$?
    if [ $exit -eq 0 ]; then
      echo "$text" | ${getExe' pkgs.wl-clipboard "wl-copy"}
      ${notifySend} --transient -t 5000 "Text Copied" "$text"
    else
      ${notifySend} --transient --urgency=critical -t 5000 "Screenshot" "Failed to copy text"
    fi
  '';

  modifyBrightness = pkgs.writeShellScript "hypr-modify-brightness" ''
    ${throttleHyprlandRepeatBind "brightness" 10}
    ${getExe pkgs.brightnessctl} set -e4 "$1"
    brightness=$(${getExe pkgs.brightnessctl} get --percentage)
    ${notifySend} --transient --urgency=low -t 2000 \
      -h 'string:x-canonical-private-synchronous:brightness' "Display" "Brightness $brightness%"
  '';

  takeScreenshot = getExe (
    pkgs.writeShellApplication {
      name = "hypr-screenshot";
      runtimeInputs = with pkgs; [
        hyprland
        hyprpicker
        libnotify
        wl-clipboard
        grim
        jq
        slurp
        satty
        procps
        app2unit
      ];
      text = ''
        output_dir="''${XDG_SCREENSHOTS_DIR:-''${XDG_PICTURES_DIR:-$HOME}}"
        date=$(date +'%Y%m%d-%H%M%S')

        action=''${1:-""}
        subject=''${2:-""}
        output_file=''${3:-""}

        if [[ $action != "save" && $action != "copy" && $subject != "area" && $subject != "output" ]]; then
          echo "Usage: wl-screenshot copy|save area|output"
          exit 1
        fi

        if [[ -z $output_file ]]; then
          if [[ $action == "copy" ]]; then
            output_file="$(mktemp "/tmp/screenshot-$date-XXXX.png")"
            message="Image saved to $output_file and copied to the clipboard"
          else
            output_file="$output_dir/$date.png"
            message="Image saved to $output_file"
          fi
        fi

        die() {
          pkill hyprpicker || true
          exit 1
        }

        if [[ $subject == "output" ]]; then
          output=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
          grim -o "$output" "$output_file"
        elif [[ $subject == "area" ]]; then
          hyprpicker --render-inactive --no-zoom &
          sleep 0.2

          geom=$(slurp -d || die)
          [[ -z $geom ]] && die
          grim -g "$geom" "$output_file" || die
        fi

        pkill hyprpicker || true

        if [[ $output_file == "-" ]]; then
          exit 0
        else
          wl-copy --type image/png < "$output_file"
        fi

        notify_action=$(notify-send --action 'default=Edit image' --icon "$output_file" Screenshot "$message")
        if [[ $notify_action = "default" ]]; then
          [[ $action == "copy" ]] && output_edit_file="$output_dir/$date.png" || output_edit_file="$output_dir/$date-edit.png"
          app2unit -t service satty --filename "$output_file" --output-filename "$output_edit_file" --font-family "${desktop.style.font.family}" &
        elif [[ $action == "copy" ]]; then
          rm "$output_file"
        fi
      '';
    }
  );
in
{
  # Force secondaryModKey VM variant because binds are repeated on host
  categoryConfig.modKey = mkIf vmVariant (lib.mkVMOverride cfg.secondaryModKey);

  ns.desktop.hyprland.extraConf = # lua
    ''
      local function notify(sync_id, title, message)
        hl.exec_cmd(
          "${notifySend} --transient --urgency=low -t 2000 "
          .. "-h 'string:x-canonical-private-synchronous:" .. sync_id .. "' "
          .. "'" .. title .. "' '" .. message .. "'"
        )
      end

      function toggle_floating()
        local w = hl.get_active_window()
        if w == nil then return end
        if not w.floating then
          hl.dispatch(hl.dsp.window.float({ action = "enable" }))
          hl.dispatch(hl.dsp.window.resize({ x = "75%", y = "75%", relative = false }))
          hl.dispatch(hl.dsp.window.center())
        else
          hl.dispatch(hl.dsp.window.float({ action = "disable" }))
        end
      end

      -- Same as maximize dispatcher except it does nothing if the
      -- active workspace holds a single non-fullscreen tiled window meaning
      -- the client is already effectively maximized.
      function toggle_maximize()
        local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
        if ws ~= nil and ws.windows == 1 and not ws.has_fullscreen then
          local w = hl.get_active_window()
          if w ~= nil and not w.floating then return end
        end
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" }))
      end

      function make_16_by_9()
        local w = hl.get_active_window()
        if w == nil then return end
        local width = w.size.x
        hl.dispatch(hl.dsp.window.resize({
          x = width,
          y = math.floor((width * 9) / 16),
          relative = false,
        }))
      end

      function scale_tablet_to_window()
        local tablet_width = 152
        local tablet_height = 95
        local w = hl.get_active_window()
        if w == nil then return end
        local width = w.size.x
        local height = w.size.y
        local pos_x = w.at.x
        local pos_y = w.at.y
        local new_width = math.floor((height * tablet_width) / tablet_height)
        local new_height = math.floor((width * tablet_height) / tablet_width)

        local region_width, region_height, region_pos_x, region_pos_y
        if (width - new_width) < 0 then
          region_height = new_height
          region_width = width
          region_pos_x = pos_x
          region_pos_y = pos_y + math.floor((height - new_height) / 2)
        else
          region_height = height
          region_width = new_width
          region_pos_x = pos_x + math.floor((width - new_width) / 2)
          region_pos_y = pos_y
        end

        hl.config({
          input = {
            tablet = {
              region_size = region_width .. " " .. region_height,
              output = "",
              absolute_region_position = true,
              region_position = region_pos_x .. " " .. region_pos_y,
            },
          },
        })
        notify("hypr-scale-tablet", "Hyprland", "Scaled tablet to active window")
      end

      function toggle_freeze()
        local w = hl.get_active_window()
        if w == nil then return end
        hl.exec_cmd("${freezeUnit} " .. w.pid)
      end

      function zoom(direction)
        local factor = hl.get_config("cursor.zoom_factor")
        if factor < 1 then factor = 1 end
        if direction == "in" then
          factor = factor * 1.25
        else
          factor = factor / 1.25
        end
        hl.config({ cursor = { zoom_factor = factor } })
      end

      function reset_zoom()
        hl.config({ cursor = { zoom_factor = 1 } })
      end

      function move_to_next_empty()
        local w = hl.get_active_window()
        local fullscreen = w ~= nil and w.fullscreen ~= nil and w.fullscreen ~= 0
        hl.dispatch(hl.dsp.window.move({ workspace = "emptym" }))
        if fullscreen then
          hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = -1 }))
        end
      end

      -- Toggle special workspace open on any monitor rather than just the
      -- active monitor. Ensures that only a single special workspace can be
      -- opened across all monitors at a time.
      function global_toggle_special_workspace(name)
        local target = "special:" .. name
        for _, m in ipairs(hl.get_monitors()) do
          local ws = m.active_special_workspace
          if ws ~= nil and ws.name == target then
            if not m.focused then
              -- first toggle will pull the special workspace to the focused monitor
              hl.dispatch(hl.dsp.workspace.toggle_special(name))
            end
            hl.dispatch(hl.dsp.workspace.toggle_special(name))
            return
          end
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
      end

      -- General
      hl.bind(mod_shift_ctrl .. " + Q", hl.dsp.exec_cmd("loginctl terminate-session \"$XDG_SESSION_ID\""))
      hl.bind(mod .. " + ${cfg.killActiveKey}", hl.dsp.window.close())
      hl.bind(mod .. " + C", toggle_floating)
      hl.bind(mod .. " + E", toggle_maximize)
      hl.bind(mod_shift .. " + E", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
      hl.bind(mod_shift .. " + Z", hl.dsp.window.pin())
      hl.bind(mod .. " + R", hl.dsp.layout("splitratio 1 exact"))
      hl.bind(mod_shift .. " + R", make_16_by_9)
      hl.bind(mod_shift_ctrl .. " + V", hl.dsp.exec_cmd("${syncClipboard}"))
      hl.bind(mod .. " + Y", scale_tablet_to_window)
      hl.bind(mod .. " + P", toggle_freeze)

      -- Movement
      hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
      hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))
      hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
      hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
      hl.bind(mod_shift_ctrl .. " + H", hl.dsp.window.move({ direction = "l" }))
      hl.bind(mod_shift_ctrl .. " + L", hl.dsp.window.move({ direction = "r" }))
      hl.bind(mod_shift_ctrl .. " + K", hl.dsp.window.move({ direction = "u" }))
      hl.bind(mod_shift_ctrl .. " + J", hl.dsp.window.move({ direction = "d" }))
      hl.bind(mod .. " + mouse:275", hl.dsp.focus({ workspace = "m-1" }))
      hl.bind(mod .. " + mouse:276", hl.dsp.focus({ workspace = "m+1" }))
      hl.bind(mod_shift .. " + Left", hl.dsp.window.move({ workspace = "r-1" }))
      hl.bind(mod_shift .. " + Right", hl.dsp.window.move({ workspace = "r+1" }))
      hl.bind(mod_shift .. " + J", hl.dsp.focus({ workspace = "m-1" }))
      hl.bind(mod_shift .. " + K", hl.dsp.focus({ workspace = "m+1" }))
      hl.bind(mod .. " + mouse_down", function() zoom("in") end)
      hl.bind(mod .. " + mouse_up", function() zoom("out") end)
      hl.bind(mod_shift .. " + mouse_up", reset_zoom)
      hl.bind(mod .. " + Equal", function() zoom("in") end)
      hl.bind(mod .. " + Minus", function() zoom("out") end)
      hl.bind(mod_shift .. " + Minus", reset_zoom)

      -- Monitors
      hl.bind(mod_shift .. " + H", hl.dsp.focus({ monitor = "l" }))
      hl.bind(mod_shift .. " + L", hl.dsp.focus({ monitor = "r" }))
      hl.bind(mod .. " + TAB", hl.dsp.focus({ monitor = "+1" }))
      hl.bind(mod_shift .. " + TAB", hl.dsp.workspace.move({ monitor = "+1" }))
      hl.bind("XF86AudioMedia", function()
        hl.timer(function()
          hl.dispatch(hl.dsp.dpms({ monitor = "${device.primaryMonitor.name}" }))
        end, { timeout = 1000, type = "oneshot" })
      end)

      -- Workspaces
      hl.bind(mod .. " + N", hl.dsp.focus({ workspace = "previous_per_monitor" }))
      hl.bind(mod .. " + M", hl.dsp.focus({ workspace = "emptym" }))
      hl.bind(mod_shift .. " + M", move_to_next_empty)
      hl.bind(mod_shift_ctrl .. " + M", hl.dsp.window.move({ workspace = "emptym", follow = false }))
      hl.bind(mod .. " + A", function() global_toggle_special_workspace("scratch1") end)
      hl.bind(mod .. " + S", function() global_toggle_special_workspace("scratch2") end)
      hl.bind(mod .. " + D", function() global_toggle_special_workspace("scratch3") end)
      hl.bind(mod .. " + F", function() global_toggle_special_workspace("scratch4") end)
      hl.bind(mod_shift .. " + A", hl.dsp.window.move({ workspace = "special:scratch1", follow = false }))
      hl.bind(mod_shift .. " + S", hl.dsp.window.move({ workspace = "special:scratch2", follow = false }))
      hl.bind(mod_shift .. " + D", hl.dsp.window.move({ workspace = "special:scratch3", follow = false }))
      hl.bind(mod_shift .. " + F", hl.dsp.window.move({ workspace = "special:scratch4", follow = false }))
      for i = 0, 9 do
        local ws = (i == 0) and 10 or i
        hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = ws }))
        hl.bind(mod_shift .. " + " .. i, hl.dsp.window.move({ workspace = ws }))
        hl.bind(mod_shift_ctrl .. " + " .. i, hl.dsp.window.move({ workspace = ws, follow = false }))
      end

      -- Dwindle
      hl.bind(mod .. " + X", hl.dsp.layout("togglesplit"))
      hl.bind(mod_shift .. " + X", hl.dsp.layout("swapsplit"))

      -- Resize
      hl.bind(mod .. " + Right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
      hl.bind(mod .. " + Left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
      hl.bind(mod .. " + Up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
      hl.bind(mod .. " + Down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })

      -- Mouse
      hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- Screenshots
      hl.bind("Print", hl.dsp.exec_cmd("${takeScreenshot} copy area"))
      hl.bind(mod .. " + I", hl.dsp.exec_cmd("${takeScreenshot} copy output"))
      hl.bind(mod_shift .. " + Print", hl.dsp.exec_cmd("${takeScreenshot} save area"))
      hl.bind(mod_shift .. " + I", hl.dsp.exec_cmd("${takeScreenshot} save output"))
      hl.bind(mod_shift_ctrl .. " + C", hl.dsp.exec_cmd("${copyScreenshotText}"))

      -- Gestures
      hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
      hl.gesture({ fingers = 4, direction = "swipe", scale = 2, action = "resize" })
      hl.gesture({ fingers = 4, direction = "swipe", mods = "ALT", scale = 2, action = "move" })
      hl.gesture({ fingers = 3, direction = "pinch", action = "fullscreen", mode = "maximize" })
      hl.gesture({ fingers = 4, direction = "pinch", action = "fullscreen" })
      hl.gesture({ fingers = 3, direction = "up", action = "special", workspace_name = "scratch2" })
      hl.gesture({ fingers = 3, direction = "down", action = "special", workspace_name = "scratch3" })

      ${optionalString (device.backlight != null)
        # nix
        ''
          hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${modifyBrightness} 3%+"), { repeating = true })
          hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${modifyBrightness} 3%-"), { repeating = true })
        ''
      }

      -- Layer rules
      hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })

      -- Submaps
      -- disables all keybinds
      hl.bind(mod .. " + Delete", hl.dsp.submap("Grab"))
      hl.define_submap("Grab", function()
        hl.bind(mod_shift .. " + Delete", hl.dsp.submap("reset"))
      end)
    '';

  programs.zsh.initContent = # bash
    ''
      toggle-dpms() {
        active_monitor=$(hyprctl activeworkspace | jaq -r '.monitor')
        sleep 2 && hyprctl dispatch dpms toggle "$active_monitor"
      }
    '';
}
