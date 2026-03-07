# https://github.com/zellij-org/zellij/issues/865
# https://github.com/zellij-org/zellij/issues/3090
# https://github.com/zellij-org/zellij/issues/4641
# https://github.com/zellij-org/zellij/issues/4130
# https://github.com/zellij-org/zellij/issues/3357
{
  lib,
  pkgs,
  config,
  inputs,
  hostname,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkOrder
    singleton
    concatLines
    getExe
    optionalString
    ;
  inherit (config.${ns}.programs.desktop) alacritty;
  inherit (config.${ns}.desktop.services) darkman;
  inherit (config.xdg) configHome dataHome;
in
{
  enableOpt = false;

  home.packages = [
    (pkgs.symlinkJoin {
      name = "zellij-wrapped";
      paths = [ pkgs.zellij ];
      postBuild =
        let
          app2unit =
            if osConfig.${ns}.system.desktop.uwsm.enable then "app2unit -t scope -s app.slice -- " else "";
        in
        ''
          ln -fs ${pkgs.writeShellScript "zellij-wrapper" ''
            config_flag=()
            wrap_opaque=""
            long_running=""
            session="${hostname}"
            graphical="''${DISPLAY-}''${WAYLAND_DISPLAY-}"

            if [[ $# -eq 0 || $1 == "attach" || $1 = "a" ]]; then
              long_running=true
            fi

            # Match zellij theme to client theme when SSHing into remote hosts. SSH
            # is configured to forward DARKMAN_THEME and we have a zsh wrapper
            # around `ssh` setting the variable.
            if [[ -z $ZELLIJ && (-n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY) && -n $DARKMAN_THEME ]]; then
              ${
                # Every new zellij session creates a `zellij --server` process. Future zellij
                # instances attaching to this session will use the environment variables of the
                # original server process. This causes issues if the session happened to be
                # created in a headless environment (in which case app2unit puts it in a
                # NoDesktop scope) then we later attach to it in a graphical environment. Stuff
                # like the clipboard and graphical keyring breaks. The solution is keep a
                # separate sesssion for `tty`, `ssh` and `desktop/local` (hostname without a
                # suffix).
                ''
                  session="''${session}-ssh"
                ''
                + (
                  if darkman.enable then
                    ''
                      config_flag=(--config "${dataHome}/darkman/variants/.config/zellij/config.kdl.$DARKMAN_THEME")
                    ''
                  else
                    ''
                      if [[ $DARKMAN_THEME == "light" ]]; then
                        ${getExe pkgs.gnused} "s/theme \"dark-theme\"/theme \"light-theme\"/" ${configHome}/zellij/config.kdl > /tmp/zellij-light-config.kdl
                        config_flag=(--config /tmp/zellij-light-config.kdl)
                      fi
                    ''
                )
              } 
            elif [[ -z $ZELLIJ && -z $graphical ]]; then
              session="''${session}-tty"
            ${optionalString alacritty.enable ''
              elif [[ -z $ZELLIJ && -n $graphical && -n $long_running && $TERM == "alacritty" ]]; then
                wrap_opaque=true
            ''}
            fi

            maybe_exec="exec"
            if [[ $wrap_opaque ]]; then
              maybe_exec=""
              reset() {
                alacritty msg config --reset
              }
              trap reset EXIT
              alacritty msg config window.opacity=1
            fi

            # If the command has no arguments attach to the default session. We
            # have to do this instead of relying on the session_name option
            # because session_name fails to resurrect sessions, it just creates
            # a new one with the same name (likely a bug)
            if [[ $# -eq 0 ]]; then
              $maybe_exec ${app2unit}${getExe pkgs.zellij} "''${config_flag[@]}" attach --create "$session"
            elif [[ $long_running ]]; then # this means we're attaching to a specific session with `attach <session>`
              $maybe_exec ${app2unit}${getExe pkgs.zellij} "''${config_flag[@]}" "$@"
            else # IPC, config, and other short running commands
              ${getExe pkgs.zellij} "''${config_flag[@]}" "$@"
            fi
          ''} $out/bin/${pkgs.zellij.meta.mainProgram}
        '';
    })
  ];

  # With `on_force_close="detach"`, if zellij has a bunch of panes and
  # processes it sometimes hangs in response to SIGTERM and delays our
  # compositor exit until the SIGKILL timeout is reached. I suspect it's
  # something to do with zellij not liking the default KillMode=control-group
  # it inherits from our terminals service. Fix is to run zellij in it's own
  # scope will KillMode=mixed. It now cleanly shuts down in all scenarios and
  # session resurrection works as expected.

  # When running zellij as a scope it seems like the server runs in a
  # persistent scope and a new scope is created whenever we attach (these
  # scopes get killed with the terminal). Might want to run zellij like this on
  # my server as well, not sure yet.
  ns.desktop.uwsm.appUnitOverrides."zellij-.scope" = ''
    [Scope]
    KillMode=mixed
  '';

  ns.desktop.darkman.switchApps."zellij" = {
    paths = [ ".config/zellij/config.kdl" ];
    extraReplacements = singleton {
      dark = ''theme "dark-theme"'';
      light = ''theme "light-theme"'';
    };
  };

  ns.persistence.directories = [ ".cache/zellij" ];

  programs.zsh = {
    shellAliases."z" = "zellij";
    # The default integration is bad cause of `zellij attach -c` behaviour
    # https://github.com/zellij-org/zellij/issues/3773
    initContent =
      mkOrder 200
        # bash
        ''
          if [[ -z $ZELLIJ && (-n $SSH_CONNECTION || -n $SSH_CLIENT || -n $SSH_TTY) && -z $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
            zellij && exit
          fi
        '';
  };

  xdg.configFile."zellij/config.kdl".text = # kdl
    ''
      keybinds clear-defaults=true {    
        shared_except "locked" {
          bind "Alt q" { Detach; }
          bind "Alt Shift q" { Quit; }
          bind "Alt Shift j" { GoToPreviousTab; }
          bind "Alt Shift k" { GoToNextTab; }
          bind "Alt j" { MoveFocus "down"; }
          bind "Alt k" { MoveFocus "up"; }
          bind "Alt l" { MoveFocus "right"; }
          bind "Alt h" { MoveFocus "left"; }
          bind "Alt Shift h" { BreakPaneLeft; }
          bind "Alt Shift l" { BreakPaneRight; }
          bind "Alt e" { ToggleFocusFullscreen; }
          bind "Alt x" { NewPane "down"; }
          bind "Alt v" { NewPane "right"; }
          bind "Alt Shift r" { SwitchToMode "renametab"; TabNameInput 0; }
          bind "Alt c" { TogglePaneEmbedOrFloating; }
          bind "Alt m" { NewTab; }
          bind "Alt Enter" { NewPane; }
          bind "Alt Shift Enter" { NewTab; }
          bind "Alt n" { ToggleTab; }
          bind "Alt w" { CloseTab; }
          bind "Alt Shift w" { CloseFocus; }
          bind "Alt s" { ToggleFloatingPanes; }
          bind "Alt [" { PreviousSwapLayout; }
          bind "Alt ]" { NextSwapLayout; }
          bind "Alt g" { SwitchToMode "locked"; }
          bind "Alt ." { MoveTab "right"; }
          bind "Alt ," { MoveTab "left"; }
          bind "Alt p" { TogglePanePinned; }
          bind "Alt Shift p" { ToggleGroupMarking; }
          bind "Alt u" { HalfPageScrollUp; }
          bind "Alt d" { HalfPageScrollDown; }
          bind "Alt a" {
            Run "lazygit" {
              close_on_exit true
              floating true
              x "0"
              y "0"
              width "100%"
              height "100%"
            }
          }

          bind "Alt 1" { GoToTab 1; }
          bind "Alt 2" { GoToTab 2; }
          bind "Alt 3" { GoToTab 3; }
          bind "Alt 4" { GoToTab 4; }
          bind "Alt 5" { GoToTab 5; }
          bind "Alt 6" { GoToTab 6; }
          bind "Alt 7" { GoToTab 7; }
          bind "Alt 8" { GoToTab 8; }
          bind "Alt 9" { GoToTab 9; }

          bind "Alt left" { Resize "Increase left"; }
          bind "Alt down" { Resize "Increase down"; }
          bind "Alt up" { Resize "Increase up"; }
          bind "Alt right" { Resize "Increase right"; }

          bind "Alt +" { Resize "Increase"; }
          bind "Alt -" { Resize "Decrease"; }
          bind "Alt =" { Resize "Increase"; }
        }
        locked {
          bind "Ctrl g" { SwitchToMode "normal"; }
        }

        shared_except "locked" "search" {
          bind "Alt /" { SwitchToMode "entersearch"; }
        }
        scroll {
          bind "s" { SwitchToMode "entersearch"; SearchInput 0; }
          bind "e" { EditScrollback; SwitchToMode "normal"; }
        }
        shared_except "locked" "scroll" {
          bind "Alt z" { SwitchToMode "scroll"; }
        }
        entersearch {
          bind "Ctrl c" { SwitchToMode "scroll"; }
          bind "esc" { SwitchToMode "scroll"; }
          bind "enter" { SwitchToMode "search"; }
        }
        search {
          bind "Shift n" { Search "up"; }
          bind "n" { Search "down"; }
          bind "c" { SearchToggleOption "CaseSensitivity"; }
          bind "o" { SearchToggleOption "WholeWord"; }
          bind "w" { SearchToggleOption "Wrap"; }
        }
        shared_among "scroll" "search" {
          bind "u" { HalfPageScrollUp; }
          bind "d" { HalfPageScrollDown; }
          bind "Shift u" { PageScrollUp; }
          bind "Shift d" { PageScrollDown; }
          bind "Shift g" { ScrollToBottom; }
          bind "g" { ScrollToTop; }
          bind "j" { ScrollDown; }
          bind "k" { ScrollUp; }
        }

        shared_except "locked" "resize" {
          bind "Alt r" { SwitchToMode "resize"; }
        }
        resize {
          bind "left" { Resize "Increase left"; }
          bind "down" { Resize "Increase down"; }
          bind "up" { Resize "Increase up"; }
          bind "right" { Resize "Increase right"; }
          bind "+" { Resize "Increase"; }
          bind "-" { Resize "Decrease"; }
          bind "=" { Resize "Increase"; }
          bind "H" { Resize "Decrease left"; }
          bind "J" { Resize "Decrease down"; }
          bind "K" { Resize "Decrease up"; }
          bind "L" { Resize "Decrease right"; }
          bind "h" { Resize "Increase left"; }
          bind "j" { Resize "Increase down"; }
          bind "k" { Resize "Increase up"; }
          bind "l" { Resize "Increase right"; }
          bind "Alt r" { SwitchToMode "normal"; }
        }
        shared_except "locked" "move" {
          bind "Alt t" { SwitchToMode "move"; }
        }
        move {
          bind "left" { MovePane "left"; }
          bind "down" { MovePane "down"; }
          bind "up" { MovePane "up"; }
          bind "right" { MovePane "right"; }
          bind "h" { MovePane "left"; }
          bind "j" { MovePane "down"; }
          bind "k" { MovePane "up"; }
          bind "l" { MovePane "right"; }
          bind "n" { MovePane; }
          bind "p" { MovePaneBackwards; }
          bind "tab" { MovePane; }
          bind "Alt t" { SwitchToMode "normal"; }
        }

        shared_except "locked" "session" {
            bind "Alt o" { SwitchToMode "session"; }
        }
        session {
          bind "Alt o" { SwitchToMode "normal"; }
          bind "d" { Detach; }
          bind "a" {
            LaunchOrFocusPlugin "zellij:about" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "normal"
          }
          bind "c" {
            LaunchOrFocusPlugin "configuration" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "normal"
          }
          bind "p" {
            LaunchOrFocusPlugin "plugin-manager" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "normal"
          }
          bind "s" {
            LaunchOrFocusPlugin "zellij:share" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "normal"
          }
          bind "w" {
            LaunchOrFocusPlugin "session-manager" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "normal"
          }
        }

        shared_except "normal" "locked" "entersearch" {
          bind "enter" { SwitchToMode "normal"; }
        }
        shared_except "normal" "locked" "entersearch" "renametab" "renamepane" {
          bind "esc" { SwitchToMode "normal"; }
        }
        renametab {
          bind "esc" { UndoRenameTab; SwitchToMode "normal"; }
        }
        shared_among "renametab" "renamepane" {
          bind "Ctrl c" { SwitchToMode "normal"; }
        }
      }

      plugins {
        about location="zellij:about"
        compact-bar location="zellij:compact-bar" {
          tooltip "F1"
        }
        configuration location="zellij:configuration"
        plugin-manager location="zellij:plugin-manager"
        session-manager location="zellij:session-manager"
        status-bar location="zellij:status-bar"
        tab-bar location="zellij:tab-bar"
        welcome-screen location="zellij:session-manager" {
          welcome_screen true
        }
      }

      load_plugins {
      }
      web_client {
        font "monospace"
      }

      // Wish these options worked but attach_to_session fails to resurrect
      // sessions. I've instead scripted this behaviour above.
      // session_name "${hostname}"
      // attach_to_session true
      default_layout "compact-top-bar"
      simplified_ui false
      theme "dark-theme"
      mouse_mode true
      copy_on_select true
      advanced_mouse_actions true
      pane_frames false
      mirror_session false
      on_force_close "detach"
      scroll_buffer_size 10000
      copy_clipboard "system" // wish I could configure selection copy to primary and keybind copy to system
      auto_layout true
      session_serialization true
      serialize_pane_viewport true
      styled_underlines true
      stacked_resize true
      show_startup_tips false

      themes {
        ${concatLines (
          map
            (
              theme:
              let
                getColor =
                  color:
                  inputs.nix-colors.lib.conversions.hexToRGBString " "
                    config.${ns}.core.color-scheme.${theme}.palette.${color};
              in
              ''
                // indent
                  ${theme}-theme {
                    text_unselected {
                      base ${getColor "base04"}
                      background ${getColor "base00"}
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    text_selected {
                      base ${getColor "base00"}
                      background ${getColor "base04"}
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    ribbon_selected {
                      base ${getColor "base00"}
                      background ${getColor "base0D"}
                      emphasis_0 ${getColor "base08"}
                      emphasis_1 ${getColor "base0A"}
                      emphasis_2 ${getColor "base0E"}
                      emphasis_3 ${getColor "base0D"}
                    }
                    ribbon_unselected {
                      base ${getColor "base00"}
                      background ${getColor "base04"}
                      emphasis_0 ${getColor "base08"}
                      emphasis_1 ${getColor "base00"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    table_title {
                      base ${getColor "base0D"}
                      background 0
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    table_cell_selected {
                      base ${getColor "base00"}
                      background ${getColor "base03"}
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    table_cell_unselected {
                      base ${getColor "base04"}
                      background ${getColor "base00"}
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    list_selected {
                      base ${getColor "base00"}
                      background ${getColor "base03"}
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    list_unselected {
                      base ${getColor "base00"}
                      background ${getColor "base00"}
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0D"}
                      emphasis_3 ${getColor "base0E"}
                    }
                    frame_selected {
                      base ${getColor "base05"}
                      background 0
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0E"}
                      emphasis_3 0
                    }
                    frame_unselected {
                      base ${getColor "base03"}
                      background 0
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 ${getColor "base0C"}
                      emphasis_2 ${getColor "base0E"}
                      emphasis_3 0
                    }
                    frame_highlight {
                      base ${getColor "base0B"}
                      background 0
                      emphasis_0 ${getColor "base0E"}
                      emphasis_1 ${getColor "base0A"}
                      emphasis_2 ${getColor "base0A"}
                      emphasis_3 ${getColor "base0A"}
                    }
                    exit_code_success {
                      base ${getColor "base0B"}
                      background 0
                      emphasis_0 ${getColor "base0C"}
                      emphasis_1 ${getColor "base00"}
                      emphasis_2 ${getColor "base0E"}
                      emphasis_3 ${getColor "base0D"}
                    }
                    exit_code_error {
                      base ${getColor "base08"}
                      background 0
                      emphasis_0 ${getColor "base0A"}
                      emphasis_1 0
                      emphasis_2 0
                      emphasis_3 0
                    }
                    multiplayer_user_colors {
                      player_1 ${getColor "base0E"}
                      player_2 ${getColor "base0D"}
                      player_3 0
                      player_4 ${getColor "base0A"}
                      player_5 ${getColor "base0C"}
                      player_6 0
                      player_7 ${getColor "base08"}
                      player_8 0
                      player_9 0
                      player_10 0
                    }
                  }
              ''
            )
            [
              "light"
              "dark"
            ]
        )}

      }
    '';

  xdg.configFile."zellij/layouts/compact-top-bar.kdl".text = # kdl
    ''
      layout {
        pane size=1 borderless=true {
          plugin location="compact-bar" 
        }
        pane
      } 
    '';

  xdg.configFile."zellij/layouts/compact-top-bar.swap.kdl".text = # kdl
    ''
      tab_template name="ui" {
         pane size=1 borderless=true {
           plugin location="compact-bar"
         }
         children
      }

      swap_floating_layout name="floating" {
        floating_panes {
          pane x="10%" y="10%" width="80%" height="80%"
        }
      }

      swap_tiled_layout name="vertical" {
        ui max_panes=4 {
          pane split_direction="vertical" {
            pane
            pane { children; }
          }
        }
        ui max_panes=7 {
          pane split_direction="vertical" {
            pane { children; }
            pane { pane; pane; pane; pane; }
          }
        }
        ui max_panes=11 {
          pane split_direction="vertical" {
            pane { children; }
            pane { pane; pane; pane; pane; }
            pane { pane; pane; pane; pane; }
          }
        }
      }

      swap_tiled_layout name="horizontal" {
        ui max_panes=3 {
          pane
          pane
        }
        ui max_panes=7 {
          pane {
            pane split_direction="vertical" { children; }
            pane split_direction="vertical" { pane; pane; pane; pane; }
          }
        }
        ui max_panes=11 {
          pane {
            pane split_direction="vertical" { children; }
            pane split_direction="vertical" { pane; pane; pane; pane; }
            pane split_direction="vertical" { pane; pane; pane; pane; }
          }
        }
      }
    '';
}
