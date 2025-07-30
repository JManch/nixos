{
  lib,
  pkgs,
  inputs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    singleton
    getExe'
    optionals
    optionalString
    ;
  inherit (config.${ns}) desktop;
  inherit (osConfig.${ns}.core.device) primaryMonitor;
  hyprctl = getExe' pkgs.hyprland "hyprctl";
  colors = config.colorScheme.palette;
  labelHeight = toString (builtins.ceil (0.035 * primaryMonitor.height * primaryMonitor.scale));
  hasFingerprint = osConfig.services.fprintd.enable;
in
{
  categoryConfig.locker = {
    package = lib.${ns}.addPatches config.programs.hyprlock.package (
      optionals hasFingerprint [
        # Allows unlocking with fingerprint when display is off but breaks fade-in animation
        "hyprlock-dpms-off-unlock.patch"
        # Adds fingerprint initialising message to fix brief period where
        # FPRINTPROMPT is empty on launch
        "hyprlock-fingerprint-initialising-message.patch"
        # Fixes the fingerprint present prompt not being displayed. Password box
        # border color only gets update in time if animation are disabled. Need
        # to figure out how to trigger another render pass to update color
        # animations.
        "hyprlock-fingerprint-present-fix.patch"
      ]
    );
    unlockCmd = "${getExe' pkgs.procps "pkill"} -USR1 hyprlock";

    defaultArgs = [
      "--grace" # hyprlock removed the grace option https://github.com/hyprwm/hyprlock/issues/782
      "5"
    ];

    immediateArgs = [
      "--no-fade-in"
      "--grace"
      "0"
    ];

    postUnlockScript = optionalString hasFingerprint "${hyprctl} dispatch dpms on";
  };

  programs.hyprlock = {
    enable = true;
    package = inputs.hyprlock.packages.${pkgs.system}.default;
    settings = {
      general.hide_cursor = true;
      animations.enabled = !hasFingerprint; # because of our fingerprint present patch

      auth = {
        pam.enabled = true;

        fingerprint = {
          enabled = hasFingerprint;
          initialising_message = "Scan fingerprint to unlock...";
          ready_message = "Scan fingerprint to unlock...";
          present_message = "Scanning fingerprint...";
        };
      };

      background = singleton {
        monitor = "";
        path = "screenshot";
        blur_size = 2;
        blur_passes = 3;
      };

      label = {
        monitor = "";
        text = "$TIME";
        color = "0xff${colors.base07}";
        font_size = builtins.ceil (0.046875 * primaryMonitor.width * primaryMonitor.scale);
        font_family = desktop.style.font.family;
        position = "0, ${labelHeight}";
        halign = "center";
        valign = "center";
      };

      input-field = singleton {
        monitor = "";
        size = "${
          toString (builtins.ceil (0.175 * primaryMonitor.width * primaryMonitor.scale))
        }, ${labelHeight}";
        fade_on_empty = false;
        outline_thickness = 3;
        dots_size = 0.2;
        dots_spacing = 0.2;
        dots_center = true;
        inner_color = "0xff${colors.base00}";
        outer_color = "0xff${colors.base07}";
        font_color = "0xff${colors.base07}";
        check_color = "0xff${colors.base0D}";
        fail_color = "0xff${colors.base08}";
        placeholder_text = "<span foreground=\"##${colors.base03}\">${
          if hasFingerprint then "$FPRINTPROMPT" else "Password..."
        }</span>";
        fail_text = "<span foreground=\"##${colors.base08}\">Authentication failed</span>";
        hide_input = false;
        position = "0, -${labelHeight}";
        rounding = desktop.style.cornerRadius;
        halign = "center";
        valign = "center";
      };
    };
  };
}
