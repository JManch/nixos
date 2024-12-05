{
  ns,
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    getExe'
    optional
    optionalString
    singleton
    ;
  inherit (config.${ns}.programs) mpv;
  inherit (config.${ns}) desktop;
  inherit (config.home) homeDirectory;
  impermanence = osConfig'.${ns}.system.impermanence or null;
  cfg = config.${ns}.programs.firefox;
in
mkIf (cfg.enable && (osConfig'.${ns}.system.desktop.enable or true)) {
  assertions = lib.${ns}.asserts [
    (cfg.runInRam -> (impermanence.enable or false))
    "Firefox run in RAM option can only be used on hosts with impermanence enabled"
  ];

  programs.firefox = {
    enable = true;

    package = mkIf cfg.runInRam (
      # Can't use pkgs.symlinkJoin here because home-manager wraps this package
      pkgs.firefox.overrideAttrs (old: {
        buildCommand =
          let
            systemctl = getExe' pkgs.systemd "systemctl";
            notifySend = getExe pkgs.libnotify;
          in
          old.buildCommand
          # bash
          + ''
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
          "media.ffmpeg.vaapi.enabled" = ((osConfig'.${ns}.device.gpu.type or true) != null);

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

        userChrome = ''
          * {
            font-family: "${desktop.style.font.family}" !important;
            font-size: 15px !important;
          }

          ${optionalString cfg.hideToolbar (
            builtins.readFile (
              let
                src = pkgs.fetchFromGitHub {
                  owner = "MrOtherGuy";
                  repo = "firefox-csshacks";
                  rev = "fe0cb2cb7bdd10471973d5713ffe1a9e6d2feaef";
                  hash = "sha256-xUDZO3n1QhGhFKuZvrYGsnhMiA3n15o/y7egSUrJffo=";
                };
              in
              pkgs.runCommand "firefox-hide-toolbar-css" { buildInputs = [ pkgs.gnused ]; } ''
                install -m644 "${src}/chrome/autohide_toolbox.css" $out
                # Preferred activation distance
                sed 's/^  --uc-toolbox-rotation:.*/  --uc-toolbox-rotation: 70deg;/' -i $out
                # Without this replacement the tab bar has a black background
                sed 's/^@media  (-moz-platform: windows){/@media {/' -i $out
              ''
            )
          )}
        '';
      };
    };
  };

  # Use systemd to synchronise Firefox data with persistent storage. Allows for
  # running Firefox on tmpfs with improved performance.

  # Ideally we would make the sync service a strict dependency of
  # graphical-session.target to ensure that firefox cannot be launched before
  # the sync has finished (if firefox launches it creates files and breaks
  # the sync). However, I don't want graphical-session.target to be delayed
  # ~10 secs every boot until the sync finishes. Instead, I wrap the firefox
  # package to prevent launch unless sync has finished. That way I can use
  # other applications until firefox is ready.
  systemd.user =
    let
      rsync = getExe pkgs.rsync;
      fd = getExe pkgs.fd;
      persistDir = "/persist/${homeDirectory}/.mozilla/";
      tmpfsDir = "${homeDirectory}/.mozilla/";

      syncToTmpfs = # bash
        ''
          # Do not delete the existing Nix store links when syncing
          ${fd} -Ht l --base-directory "${tmpfsDir}" | \
            ${rsync} -ah --no-links --delete --info=stats1 \
            --exclude-from=- "${persistDir}" "${tmpfsDir}"
        '';

      syncToPersist = # bash
        ''
          ${rsync} -ah --no-links --delete --info=stats1 \
            "${tmpfsDir}" "${persistDir}"
        '';
    in
    mkIf cfg.runInRam {
      services.firefox-persist-init = {
        Unit = {
          Description = "Firefox persist initialiser";
          X-SwitchMethod = "keep-old";
          # We don't want graphical-session.target activation to be delayed
          # until this service is active.
          After = "graphical-session.target";
          PartOf = "graphical-session.target";
        };

        Service = {
          Type = "oneshot";
          Slice = [ "app-graphical.slice" ];
          ExecStart =
            (pkgs.writeShellScript "firefox-persist-init" # bash
              ''
                if [ ! -e "${persistDir}" ]; then
                  ${syncToPersist}
                else
                  ${syncToTmpfs}
                fi
              ''
            ).outPath;
          # Backup on shutdown
          ExecStop = syncToPersist;
          RemainAfterExit = true;
        };

        Install.WantedBy = [ "graphical-session.target" ];
      };

      services.firefox-persist-sync = {
        Unit = {
          Description = "Firefox persist synchroniser";
          X-SwitchMethod = "keep-old";
          After = [ "firefox-persist-init.service" ];
          Requisite = [
            "firefox-persist-init.service"
            "graphical-session.target"
          ];
        };

        Service = {
          Type = "oneshot";
          Slice = [ "background-graphical.slice" ];
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
          ExecStart =
            (pkgs.writeShellScript "firefox-persist-sync" ''
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
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/mpv" = mkIf mpv.enable [ "open-in-mpv.desktop" ];

    # Set firefox as default browser
    "default-web-browser" = [ "firefox.desktop" ];
    "text/html" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };

  backups.firefox = mkIf cfg.backup {
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
      inherit (config.${ns}.desktop.hyprland) modKey;
    in
    [
      "${modKey}, Backspace, exec, app2unit firefox"
      "${modKey}SHIFT, Backspace, workspace, emptym"
      "${modKey}SHIFT, Backspace, exec, app2unit firefox"
    ];

  ${ns}.desktop.hyprland.eventScripts.windowtitlev2 = singleton (pkgs.writeShellScript "hypr-bitwarden-windowtitlev2" ''
    if [[ $2 == "Extension: (Bitwarden Password Manager) - — Mozilla Firefox" ]]; then
      hyprctl --batch "\
        dispatch setfloating address:0x$1; \
        dispatch resizewindowpixel exact 20% 50%, address:0x$1; \
        dispatch centerwindow; \
      "
    fi
  '').outPath;
}
