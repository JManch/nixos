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
    mkForce
    mapAttrs
    hiPrio
    mapAttrs'
    getExe
    concatMapStringsSep
    singleton
    substring
    concatMap
    nameValuePair
    attrValues
    mkVMOverride
    optionalAttrs
    listToAttrs
    mkOption
    types
    mkAliasOptionModule
    ;
  inherit (lib.${ns}) addPatches sliceSuffix;
  inherit (config.${ns}) desktop;
  inherit (osConfig.${ns}.core.device) hassIntegration;
  inherit (config.${ns}.services.hass) curlCommand;
  inherit (config.xdg) dataHome;
  inherit (config.services) darkman;
in
{
  asserts = [
    (cfg.switchMethod == "hass" -> hassIntegration.enable)
    "Darkman 'hass' switch mode requires the device to have hass integration enabled"
  ];

  imports = [
    (mkAliasOptionModule
      [ ns "desktop" "darkman" ]
      [
        ns
        "desktop"
        "services"
        "darkman"
      ]
    )
  ];

  opts = {
    switchMethod = mkOption {
      type = types.enum [
        "manual"
        "coordinates"
        "hass"
      ];
      default = "coordinates";
      description = ''
        Manual means the theme will not switch automatically. Coordinates
        uses the configured longitude and latitude to switch at sunrise and
        sunset. Hass uses a home assistant brightness entity to select the
        theme.
      '';
    };

    hassEntity = mkOption {
      type = types.str;
      description = ''
        Hass binary_sensor entity to determine dark mode toggle
      '';
    };

    switchScripts = mkOption {
      type = types.attrsOf (types.functionTo types.lines);
      default = { };
      description = ''
        Attribute set of functions that accept a string "dark" or "light"
        and provide a script for making the theme switch.
      '';
    };

    switchApps = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            paths = mkOption {
              type = with types; listOf str;
              default = [ ];
              example = [
                "waybar/config"
                "waybar/style.css"
              ];
              description = ''
                List of paths relative to $HOME that point to files managed
                by home-manager that contain hex colors we want to switch
              '';
            };

            format = mkOption {
              type = with types; functionTo str;
              default = c: c;
              example = c: "#${c}";
              description = ''
                Function to apply a custom color format. For example, if the
                configuration file expects colors to be prefixed with #.
              '';
            };

            reloadScript = mkOption {
              type = types.lines;
              default = "";
              description = "Bash script to execute when switching colorschemes";
            };

            colorOverrides = mkOption {
              type = types.attrs;
              default = { };
              example = {
                base00 = {
                  dark = config.${ns}.core.color-scheme.dark.palette.base00;
                  light = config.${ns}.core.color-scheme.light.palette.base02;
                };
              };
              description = ''
                Attribute set of base colors with dark and light variants that will
                override the default base color map.
              '';
            };

            extraReplacements = mkOption {
              type = with types; listOf attrs;
              default = [ ];
              example = [
                {
                  dark = "opacity = 0.7";
                  light = "opacity = 1";
                }
              ];
              description = ''
                List of additional replacements that are not related to base
                colors. Cyclic replacements will not work.
              '';
            };
          };
        }
      );
      default = { };
      example = {
        waybar.paths = [
          "waybar/config"
          "waybar/style.css"
        ];
      };
      description = ''
        Attribute set of applications that should have color scheme switching
        applied to them.
      '';
    };
  };

  services.darkman = {
    enable = true;
    package = addPatches pkgs.darkman [ "darkman-no-initial-switch.patch" ];
    darkModeScripts = mapAttrs (_: v: v "dark") cfg.switchScripts;
    lightModeScripts = mapAttrs (_: v: v "light") cfg.switchScripts;

    settings =
      {
        usegeoclue = false;
      }
      // optionalAttrs (cfg.switchMethod == "coordinates") {
        lat = 50.8;
        lng = -0.1;
      };
  };

  systemd.user.services.darkman = {
    Unit.After = [ "graphical-session.target" ];
    Service.Slice = mkForce "background${sliceSuffix osConfig}.slice";
  };

  # Remove the "Toggle darkman" desktop entry
  home.packages = [
    (hiPrio (
      pkgs.runCommand "darkman-desktop-disable" { } ''
        install ${darkman.package}/share/applications/darkman.desktop -Dt $out/share/applications
        echo "NoDisplay=true" >> $out/share/applications/darkman.desktop
      ''
    ))
  ];

  xdg.portal.config.common = {
    "org.freedesktop.impl.portal.Settings" = [ "darkman" ];
  };

  ns.desktop.hyprland.binds = [
    "${desktop.hyprland.modKey}SHIFT, C, exec, ${getExe darkman.package} toggle"
  ];

  systemd.user.services.darkman-luminence-switcher = mkIf (cfg.switchMethod == "hass") {
    Unit = {
      Description = "Switch darkman theme based on home assistant brightness entity";
      Requires = [ "darkman.service" ];
      After = [ "darkman.service" ];
    };

    Service = {
      Slice = "background${sliceSuffix osConfig}.slice";
      ExecStart = getExe (
        pkgs.writeShellApplication {
          name = "darkman-luminence-switcher";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.jaq
            darkman.package
          ];
          text = ''
            set +e
            current_theme=$(darkman get)
            switch_theme() {
              if [ "$1" != "$(darkman get)" ]; then
                darkman set "$1"
                current_theme="$1"
              fi
            }

            while true
            do
              state=$(${curlCommand { endpoint = "states/binary_sensor.${cfg.hassEntity}"; }} | jaq -r .state)
              if [[ "$state" = "on" && ("$current_theme" = "dark" || "$current_theme" = "null") ]]; then
                switch_theme "light"
              elif [[ "$state" = "off" && ("$current_theme" = "light" || "$current_theme" = "null") ]]; then
                switch_theme "dark"
              elif [ "$current_theme" = "null" ]; then
                darkman set dark
              fi
              sleep 180
            done
          '';
        }
      );
    };

    Install.WantedBy = [ "darkman.service" ];
  };

  # How this works:
  #
  # If a module wants to enable theme switching it adds an entry to the
  # switchApps option attribute set. The entry contains paths to the xdg config
  # files generated by the module. We change the target of the files home.file
  # attribute to .local/share/darkman/variants/PATH.dark where PATH is the
  # original file path relative to $HOME. It's named .dark because it is
  # assumed that all apps are originally configured as dark themes.
  #
  # To generate the light theme, we use a script that runs every time hm
  # activates. The script uses sed to replace all occurences of base16 dark
  # colors with their base16 light counterpart. This generates a new file at
  # .local/share/darkman/variants/PATH.light. Now we have a light and dark
  # variant, but the original config file does not exist. We create a new
  # home.file entry with a target of PATH (the original config path) and source
  # being an outOfStoreSymlink that points to darkman/variant/PATH. The file
  # darkman/variant/PATH is generated in our home manager activation script and
  # its contents is swapped to darkman/variant/PATH.light or
  # darkman/variant/PATH.dark whenever darkman performs a theme switch. Because
  # the file is created by us and pointed to by a symlink, we can safely modify
  # it without home manager complaining.
  #
  # Key points:
  # - All theme variants are stored in ~/.local/share/darkman/variants
  # - Application config files are replaced with outOfStoreSymlinks to ~/.local/share/darkman/variants/*
  # - Configs in ~/.local/share/darkman/variants/* are modified to switch themes

  # Modify the existing home file entry to point at our custom
  # target and create a new home file entry with the original
  # target. This is the config file we will modify at runtime to switch
  # themes as it uses an out of store symlink.
  home.file = listToAttrs (
    concatMap (
      value:
      (concatMap (
        path:
        let
          absPath = "${config.home.homeDirectory}/${path}";
        in
        [
          (nameValuePair absPath { target = mkForce ".local/share/darkman/variants/${path}.dark"; })
          (nameValuePair "darkman-${path}" {
            target = absPath;
            source = config.lib.file.mkOutOfStoreSymlink "${dataHome}/darkman/variants/${path}";
          })
        ]
      ) value.paths)
    ) (attrValues cfg.switchApps)
  );

  # Add a home-manager activation script for generating the light
  # theme variants
  home.activation =
    let
      inherit (lib.hm.dag) entryAfter;
      inherit (config.${ns}.core.color-scheme) colorMap;
    in
    mapAttrs' (
      switchApp: switchConfig:
      nameValuePair "generate-${switchApp}-light-variants" (
        entryAfter [ "writeBoundary" ] (
          concatMapStringsSep "\n" (
            path:
            let
              colors = colorMap // switchConfig.colorOverrides;

              replacements =
                # We have to insert a placeholder for color replacements to
                # account for cycles
                (map (
                  base:
                  let
                    inherit (base) light dark;
                    lightFormatted = switchConfig.format light;
                    lightStart = substring 0 3 lightFormatted;
                    lightEnd = substring 3 (builtins.stringLength lightFormatted) lightFormatted;
                  in
                  {
                    dark = switchConfig.format dark;
                    light = "${lightStart}@@@DARKMAN_PLACEHOLDER@@@${lightEnd}";
                  }
                ) (attrValues colors))
                ++ singleton {
                  dark = "@@@DARKMAN_PLACEHOLDER@@@";
                  light = "";
                }
                ++ switchConfig.extraReplacements;

              genLightVariantCommand = ''
                ${getExe pkgs.gnused} ${
                  concatMapStringsSep " \\\n" (r: "-e 's/${r.dark}/${r.light}/g'") replacements
                } "${dataHome}/darkman/variants/${path}.dark" > "${dataHome}/darkman/variants/${path}.light"
              '';
            in
            # bash
            ''
              if [[ -v DRY_RUN ]]; then
                cat <<EOF
                  ${genLightVariantCommand}
              EOF
              else
                ${genLightVariantCommand}
              fi

              # If the current theme is light then activate the light variant.
              # Prevents the theme resetting to dark when doing home manager
              # rebuilds.
              theme=$(${getExe darkman.package} get 2>/dev/null || echo "")
              if [ "$theme" = "light" ]; then
                run cp "${dataHome}/darkman/variants/${path}.light" "${dataHome}/darkman/variants/${path}"
              else
                # Use dark config as a placeholder in case darkman fails or is
                # too late to start
                run install -m644 "${dataHome}/darkman/variants/${path}.dark" "${dataHome}/darkman/variants/${path}"
              fi
            ''
          ) switchConfig.paths
        )
      )
    ) cfg.switchApps;

  # Create a switch script for this app that swaps our out of store
  # symlink config file with the new theme and executes the reload script
  categoryConfig.darkman = {
    switchScripts = mapAttrs (_: switchConfig: theme: ''
      ${concatMapStringsSep "\n" (path: ''
        cp "${dataHome}/darkman/variants/${path}.${theme}" "${dataHome}/darkman/variants/${path}"
      '') switchConfig.paths}
      ${switchConfig.reloadScript}
    '') cfg.switchApps;

    switchMethod = mkIf vmVariant (mkVMOverride "coordinates");
  };
}
