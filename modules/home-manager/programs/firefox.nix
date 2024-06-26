{ lib
, pkgs
, config
, osConfig
, username
, ...
}:
let
  inherit (lib) mkIf utils getExe getExe' optional;
  inherit (config.modules.programs) mpv;
  inherit (config.modules) desktop;
  inherit (osConfig.modules.system) impermanence;
  cfg = config.modules.programs.firefox;
in
mkIf (cfg.enable && osConfig.modules.system.desktop.enable)
{
  assertions = utils.asserts [
    (cfg.runInRam -> impermanence.enable)
    "Firefox run in RAM option can only be used on hosts with impermanence enabled"
  ];

  programs.firefox = {
    enable = true;

    package = mkIf cfg.runInRam (
      pkgs.firefox.overrideAttrs (old: {
        buildCommand =
          let
            systemctl = getExe' pkgs.systemd "systemctl";
            notifySend = getExe pkgs.libnotify;
          in
          old.buildCommand + /*bash*/ ''
            wrapProgram $out/bin/firefox --run "${systemctl} is-active --quiet --user firefox-persist-init \
              || { ${notifySend} -u critical -t 3000 'Firefox' 'Initial sync has not yet finished'; exit 0; }"
          '';
      })
    );

    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;

        settings = {
          # General
          "general.autoScroll" = true;
          "extensions.pocket.enabled" = false;
          # Enable userChrome.css modifications
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          # Enable hardware acceleration
          # Firefox only support VAAPI acceleration. This is natively supported
          # by AMD cards but NVIDIA cards need a translation library to go from
          # VDPAU to VAAPI.
          "media.ffmpeg.vaapi.enabled" = (osConfig.device.gpu.type != null);

          # Scrolling
          "mousewheel.default.delta_multiplier_x" = 99;
          "mousewheel.default.delta_multiplier_y" = 99;
          "mousewheel.default.delta_multiplier_z" = 99;
          "general.smoothScroll" = true;
          "general.smoothScroll.lines.durationMaxMS" = 125;
          "general.smoothScroll.lines.durationMinMS" = 125;
          "general.smoothScroll.mouseWheel.durationMaxMS" = 200;
          "general.smoothScroll.mouseWheel.durationMinMS" = 100;
          "general.smoothScroll.other.durationMaxMS" = 125;
          "general.smoothScroll.other.durationMinMS" = 125;
          "general.smoothScroll.pages.durationMaxMS" = 125;
          "general.smoothScroll.pages.durationMinMS" = 125;
          "mousewheel.system_scroll_override_on_root_content.horizontal.factor" = 175;
          "mousewheel.system_scroll_override_on_root_content.vertical.factor" = 175;
          "toolkit.scrollbox.horizontalScrollDistance" = 6;
          "toolkit.scrollbox.verticalScrollDistance" = 2;

          # UI
          "layout.css.devPixelsPerPx" = 0.9;
          "browser.compactmode.show" = true;
          "browser.uidensity" = 1;
          "browser.urlbar.suggest.engines" = false;
          "browser.urlbar.suggest.openpage" = false;
          "browser.toolbars.bookmarks.visibility" = "never";
          "browser.newtabpage.activity-stream.feeds.system.topstories" = false;
          "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts" = false;
          "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";

          # QOL
          "signon.rememberSignons" = false;
          "signon.management.page.breach-alerts.enabled" = false;
          "layout.word_select.eat_space_to_next_word" = false;
          "browser.download.useDownloadDir" = false;
          "browser.aboutConfig.showWarning" = false;
          "extensions.formautofill.creditCards.enabled" = false;
          "doms.forms.autocomplete.formautofill" = false;

          # Privacy
          "private.globalprivacycontrol.enabled" = true;
          "private.donottrackheader.enabled" = true;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.newtabpage.activity-stream.default.sites" = "";
          "extensions.getAddons.showPane" = false;
          "extensions.htmlaboutaddons.recommendations.enabled" = false;
          "browser.discovery.enabled" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.healthreport.uploadEnabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.server" = "data:,";
          "toolkit.telemetry.archive.enabled" = false;
          "toolkit.telemetry.newProfilePing.enabled" = false;
          "toolkit.telemetry.shutdownPingSender.enabled" = false;
          "toolkit.telemetry.updatePing.enabled" = false;
          "toolkit.telemetry.bhrPing.enabled" = false;
          "toolkit.telemetry.firstShutdownPing.enabled" = false;
          "toolkit.telemetry.coverage.opt-out" = true;
          "toolkit.coverage.opt-out" = true;
          "toolkit.coverage.endpoint.base" = "";
          "browser.ping-centre.telemetry" = false;
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "breakpad.reportURL" = "";
          "browser.tabs.crashReporting.sendReport" = false;
          "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
          "captivedetect.canonicalURL" = "";
          "network.captive-portal-service.enabled" = false;
          "network.connectivity-service.enabled" = false;
        };

        userChrome = /* css */ ''
          * {
            font-family: "${desktop.style.font.family}" !important;
            font-size: 15px !important;
          }

          /* Source file https://github.com/MrOtherGuy/firefox-csshacks/tree/master/chrome/autohide_toolbox.css made available under Mozilla Public License v. 2.0
          See the above repository for updates as well as full license text. */

          /* Hide the whole toolbar area unless urlbar is focused or cursor is over the toolbar */
          /* Dimensions on non-Win10 OS probably needs to be adjusted */

          /* Compatibility options for hide_tabs_toolbar.css and tabs_on_bottom.css at the end of this file */

          :root{
            --uc-autohide-toolbox-delay: 200ms; /* Wait 0.1s before hiding toolbars */
            --uc-toolbox-rotation: 70deg;  /* This may need to be lower on mac - like 75 or so */
          }

          :root[sizemode="maximized"]{
            --uc-toolbox-rotation: 70deg;
          }

          @media {
            :root:not([lwtheme]) #navigator-toolbox{ background-color: -moz-dialog !important; }
          }

          :root[sizemode="fullscreen"],
          :root[sizemode="fullscreen"] #navigator-toolbox{ margin-top: 0 !important; }

          #navigator-toolbox{
            position: fixed !important;
            display: block;
            background-color: var(--lwt-accent-color,black) !important;
            transition: transform 82ms linear, opacity 82ms linear !important;
            transition-delay: var(--uc-autohide-toolbox-delay) !important;
            transform-origin: top;
            transform: rotateX(var(--uc-toolbox-rotation));
            opacity: 0;
            line-height: 0;
            z-index: 1;
            pointer-events: none;
          }

          #navigator-toolbox:hover,
          #navigator-toolbox:focus-within{
            transition-delay: 33ms !important;
            transform: rotateX(0);
            opacity: 1;
          }
          /* This ruleset is separate, because not having :has support breaks other selectors as well */
          #mainPopupSet:has(> #appMenu-popup:hover) ~ toolbox{
            transition-delay: 33ms !important;
            transform: rotateX(0);
            opacity: 1;
          }

          #navigator-toolbox > *{ line-height: normal; pointer-events: auto }

          #navigator-toolbox,
          #navigator-toolbox > *{
            width: 100vw;
            -moz-appearance: none !important;
          }

          /* These two exist for oneliner compatibility */
          #nav-bar{ width: var(--uc-navigationbar-width,100vw) }
          #TabsToolbar{ width: calc(100vw - var(--uc-navigationbar-width,0px)) }

          /* Don't apply transform before window has been fully created */
          :root:not([sessionrestored]) #navigator-toolbox{ transform:none !important }

          :root[customizing] #navigator-toolbox{
            position: relative !important;
            transform: none !important;
            opacity: 1 !important;
          }

          #navigator-toolbox[inFullscreen] > #PersonalToolbar,
          #PersonalToolbar[collapsed="true"]{ display: none }

          /* Uncomment this if tabs toolbar is hidden with hide_tabs_toolbar.css */
           /*#titlebar{ margin-bottom: -9px }*/

          /* Uncomment the following for compatibility with tabs_on_bottom.css - this isn't well tested though */
          /*
          #navigator-toolbox{ flex-direction: column; display: flex; }
          #titlebar{ order: 2 }
          */
        '';

        userContent = /*css*/ ''
          @-moz-document url-prefix(http://lore.kernel.org/) { /* moz-only */
            /*
             * CC0-1.0 <https://creativecommons.org/publicdomain/zero/1.0/legalcode>
             * Dark color scheme using 216 web-safe colors, inspired
             * somewhat by the default color scheme in mutt.
             * It reduces eyestrain for me, and energy usage for all:
             * https://en.wikipedia.org/wiki/Light-on-dark_color_scheme
             */
            * { font-size: 100% !important;
              font-family: monospace !important;
              background:#000 !important;
              color:#ccc !important }
            pre { white-space: pre-wrap !important }

            /*
             * Underlined links add visual noise which make them hard-to-read.
             * Use colors to make them stand out, instead.
             */
            a:link { color:#69f !important;
              text-decoration:none !important }
            a:visited { color:#96f !important }

            /* quoted text in emails gets a different color */
            *.q { color:#09f !important }

            /*
             * these may be used with cgit <https://git.zx2c4.com/cgit/>, too.
             * (cgit uses <div>, public-inbox uses <span>)
             */
            *.add { color:#0ff !important } /* diff post-image lines */
            *.del { color:#f0f !important } /* diff pre-image lines */
            *.head { color:#fff !important } /* diff header (metainformation) */
            *.hunk { color:#c93 !important } /* diff hunk-header */

            /*
             * highlight 3.x colors (tested 3.18) for displaying blobs.
             * This doesn't use most of the colors available, as I find too
             * many colors overwhelming, so the default is commented out.
             */
            .hl.num { color:#f30 !important } /* number */
            .hl.esc { color:#f0f !important } /* escape character */
            .hl.str { color:#f30 !important } /* string */
            .hl.ppc { color:#f0f !important } /* preprocessor */
            .hl.pps { color:#f30 !important } /* preprocessor string */
            .hl.slc { color:#09f !important } /* single-line comment */
            .hl.com { color:#09f !important } /* multi-line comment */
            /* .hl.opt { color:#ccc !important } */ /* operator */
            /* .hl.ipl { color:#ccc !important } */ /* interpolation */

            /* keyword groups kw[a-z] */
            .hl.kwa { color:#ff0 !important }
            .hl.kwb { color:#0f0 !important }
            .hl.kwc { color:#ff0 !important }
            /* .hl.kwd { color:#ccc !important } */

            /* line-number (unused by public-inbox) */
            /* .hl.lin { color:#ccc !important } */

          } /* moz-only */
        '';
      };
    };
  };

  # Use systemd to synchronise Firefox data with persistent storage. Allows for
  # running Firefox on tmpfs with improved performance.
  systemd.user =
    let
      rsync = getExe pkgs.rsync;
      fd = getExe pkgs.fd;
      persistDir = "/persist/home/${username}/.mozilla/";
      tmpfsDir = "/home/${username}/.mozilla/";

      syncToTmpfs = /*bash*/ ''
        # Do not delete the existing Nix store links when syncing
        ${fd} -Ht l --base-directory "${tmpfsDir}" | \
          ${rsync} -ah --no-links --delete --info=stats1 \
          --exclude-from=- "${persistDir}" "${tmpfsDir}"
      '';

      syncToPersist = /*bash*/ ''
        ${rsync} -ah --no-links --delete --info=stats1 \
          "${tmpfsDir}" "${persistDir}"
      '';
    in
    mkIf cfg.runInRam {
      services.firefox-persist-init = {
        Unit = {
          Description = "Firefox persist initialiser";
          X-SwitchMethod = "keep-old";
        };

        Service = {
          Type = "oneshot";
          ExecStart = (pkgs.writeShellScript "firefox-persist-init" /*bash*/ ''
            if [ ! -e "${persistDir}" ]; then
              ${syncToPersist}
            else
              ${syncToTmpfs}
            fi
          '').outPath;
          # Backup on shutdown
          ExecStop = syncToPersist;
          RemainAfterExit = true;
        };

        # Ideally we would use "graphical-session-pre.target" here to ensure
        # that firefox cannot be launched before the sync has finished (if
        # firefox launches it creates files and breaks the sync). However, I
        # don't want to stare at a blank screen for 5 seconds every boot so
        # instead I prevent firefox launch bind from working unless sync has
        # finished. It's not too fragile because even if firefox is forcefully
        # launched within the ~5 second window, the persist-init service will
        # fail, prevent further syncs from happening, and prevent corruption.
        Install.WantedBy = [ "default.target" ];
      };

      services.firefox-persist-sync = {
        Unit = {
          Description = "Firefox persist synchroniser";
          X-SwitchMethod = "keep-old";
          After = [ "firefox-persist-init.service" ];
          Requisite = [ "firefox-persist-init.service" "graphical-session.target" ];
        };

        Service = {
          Type = "oneshot";
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
          ExecStart = (pkgs.writeShellScript "firefox-persist-sync" ''
            ${syncToPersist}
          '').outPath;
        };
      };

      timers.firefox-persist-sync = {
        Unit = {
          Description = "Firefox persist synchroniser timer";
          X-SwitchMethod = "keep-old";
        };

        Timer = {
          Unit = "firefox-persist-sync.service";
          OnCalendar = "*:0/15";
        };

        Install.WantedBy = [ "timers.target" ];
      };
    };

  # The extension must also be installed https://github.com/Baldomo/open-in-mpv
  home.packages = optional mpv.enable pkgs.open-in-mpv;
  xdg.mimeApps.defaultApplications = mkIf mpv.enable {
    "x-scheme-handler/mpv" = [ "open-in-mpv.desktop" ];
  };

  backups.firefox = {
    paths = [ ".mozilla" ];
    restore = mkIf cfg.runInRam {
      preRestoreScript = "systemctl stop --user firefox-persist-init";
      postRestoreScript = "systemctl start --user firefox-persist-init";
    };
  };

  persistence.directories = mkIf (!cfg.runInRam) [
    ".mozilla"
    ".cache/mozilla"
  ];

  desktop.hyprland.binds =
    let
      inherit (config.modules) desktop;
      firefox = getExe config.programs.firefox.finalPackage;
    in
    [
      "${desktop.hyprland.modKey}, Backspace, exec, ${firefox}"
      "${desktop.hyprland.modKey}SHIFT, Backspace, workspace, emptym"
      "${desktop.hyprland.modKey}SHIFT, Backspace, exec, ${firefox}"
    ];
}
