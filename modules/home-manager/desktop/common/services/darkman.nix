# How this works:
#
# If a module wants to enable theme switching it adds an entry to the
# switchApps option attribute set. The entry contains paths to the xdg config
# files generated by the module. We change the target of the config's
# xdg.configFile attribute to darkman/variants/PATH.dark where PATH is the
# original config path relative to xdg.configHome. It's named .dark because it
# is assumed that all apps are originally configured as dark themes.
#
# To generate the light theme, we use a script that runs every time hm
# activates. The script uses sed to replace all occurences of base16 dark
# colors with their base16 light counterpart. This generates a new file at
# darkman/variants/PATH.light. Now we have a light and dark variant; but the
# original config file does not exist. We create a new xdg.configFile entry
# with a target of PATH (the original config path) and source being an
# outOfStoreSymlink that points to darkman/variant/PATH. The file
# darkman/variant/PATH is generated in our home manager activation script and
# its contents is swapped to darkman/variant/PATH.light or
# darkman/variant/PATH.dark whenever darkman performs a theme switch. Because
# the file is created by us and pointed to by a symlink, we can safely modify
# it without home manager complaining.
#
# Key points:
# - All theme variants are stored in ~/.config/darkman/variants
# - Application config files are replaced with outOfStoreSymlinks to ~/.config/darkman/variants/...
# - Configs in ~/.config/darkman/variants/... are modified to switch themes
{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib)
    mkIf
    utils
    mapAttrs
    getExe
    concatStringsSep
    attrNames
    take
    drop
    concatMap
    nameValuePair
    attrValues
    optionalAttrs
    listToAttrs;
  inherit (config.modules) desktop;
  inherit (osConfig.device) hassIntegration;
  inherit (config.age.secrets) hassToken;
  cfg = config.modules.desktop.services.darkman;
  darkman = getExe config.services.darkman.package;

  colorSchemeSwitchingConfiguration =
    let
      inherit (config.modules.colorScheme) colorMap;
      inherit (config.xdg) configHome;
      inherit (lib.hm.dag) entryAfter;
      sed = getExe pkgs.gnused;

      genVariants = { paths, format ? c: c, colors ? colorMap, ... }: concatStringsSep "\n" (map
        (path:
          let
            baseColors = attrNames colors;
            sedCommand = /*bash*/ ''
              # Replacement have to be done over three commands to avoid cycles
              ${sed} ${concatStringsSep " " (
                # Replace first four colors with their base name
                map (base: "-e 's/${format colors.${base}.dark}/${base}/g'")
                (take 4 baseColors)
              )} "${configHome}/darkman/variants/${path}.dark" | \
              \
              ${sed} ${concatStringsSep " " (
                # Replace all but the first 4 colors with their light variant
                map (base: "-e 's/${format colors.${base}.dark}/${format colors.${base}.light}/g'")
                (drop 4 baseColors)
              )} | \
              \
              ${sed} ${concatStringsSep " " (
                # Replace the first 4 base names with their light variant
                map (base: "-e 's/${base}/${format colors.${base}.light}/g'")
                (take 4 baseColors)
              )} > "${configHome}/darkman/variants/${path}.light"
            '';
          in
            /*bash*/ ''

            if [[ -v DRY_RUN ]]; then
              cat <<EOF
                ${sedCommand}
            EOF
            else
              ${sedCommand}
            fi

            # If the current theme is light then activate the light variant.
            # Prevents the theme resetting to dark when doing home manager
            # rebuilds.
            theme=$(${darkman} get 2>/dev/null || echo "")
            if [ "$theme" = "light" ]; then
              run --quiet cp "${configHome}/darkman/variants/${path}.light" "${configHome}/darkman/variants/${path}"
            else
              # Use dark config as a placeholder incase darkman fails or is too
              # late to start
              run --quiet install -m644 "${configHome}/darkman/variants/${path}.dark" "${configHome}/darkman/variants/${path}"
            fi

          '')
        paths);

      switchScript = { paths, theme }: concatStringsSep "\n" (map
        (path: /*bash*/ ''
          cp "${configHome}/darkman/variants/${path}.${theme}" "${configHome}/darkman/variants/${path}"
        '')
        paths);
    in
    {
      xdg.configFile = listToAttrs (
        concatMap
          (value:
            (concatMap
              (path:
                [
                  (nameValuePair
                    path
                    {
                      target = "darkman/variants/${path}.dark";
                    })
                  (nameValuePair
                    "darkman-${path}"
                    {
                      target = path;
                      source = config.lib.file.mkOutOfStoreSymlink "${configHome}/darkman/variants/${path}";
                    })
                ])
              value.paths)
          )
          (attrValues cfg.switchApps));

      home.activation."generate-darkman-variants" = entryAfter [ "linkGeneration" ]
        (concatStringsSep "\n"
          (
            map (app: genVariants cfg.switchApps.${app})
              (attrNames cfg.switchApps)
          ));

      modules.desktop.services.darkman.switchScripts = mapAttrs
        (_: value:
          (theme: ''
            ${switchScript { inherit (value) paths; inherit theme;}}
            ${value.reloadScript or ""}
          '')
        )
        cfg.switchApps;
    };
in
{
  config = mkIf (cfg.enable && osConfig.usrEnv.desktop.enable) ({
    assertions = utils.asserts [
      ((cfg.switchMethod == "solar") -> hassIntegration.enable)
      "Darkman 'solar' switch mode requires the device to have hass integration enabled"
    ];

    services.darkman = {
      enable = true;
      package = pkgs.darkman.override {
        buildGoModule = args: pkgs.buildGoModule (args // rec {
          version = "2024-04-18";
          patches = [ ../../../../../patches/darkman.diff ];

          src = pkgs.fetchFromGitLab {
            owner = "WhyNotHugo";
            repo = "darkman";
            rev = "57d1bfd417b0810da919fe5cbfee384addc74f2c";
            sha256 = "sha256-MOhqlxC0aQz1692iiJUlaug9RfDyIJPnzw+4/O+2LZI=";
          };

          ldflags = [
            "-X main.Version=${version}"
            "./cmd/darkman"
          ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp darkman $out/bin
            runHook postInstall
          '';

          vendorHash = "sha256-3lILSVm7mtquCdR7+cDMuDpHihG+gDJTcQa1cM2o7ZU=";
        });
      };
      darkModeScripts = mapAttrs (_: v: v "dark") cfg.switchScripts;
      lightModeScripts = mapAttrs (_: v: v "light") cfg.switchScripts;

      settings = {
        usegeoclue = false;
      } // optionalAttrs (cfg.switchMethod == "coordinates") {
        lat = 50.8;
        lng = -0.1;
      };
    };

    # Causes portal to crash, not sure if this is a darkman problem or xdg
    # portal?
    # xdg.portal.config.common = {
    #   "org.freedesktop.impl.portal.Settings" = [ "darkman" ];
    # };

    desktop.hyprland.binds = [ "${desktop.hyprland.modKey}, F1, exec, ${darkman} toggle" ];

    systemd.user.services.darkman-solar-switcher = mkIf (cfg.switchMethod == "solar") {
      Unit = {
        Description = "Switch darkman theme based on home assistant solar power";
        Requires = [ "darkman.service" ];
        After = [ "darkman.service" ];
      };

      Service = {
        ExecStart = pkgs.writers.writePython3 "darkman-solar-switcher" { libraries = [ pkgs.python3Packages.requests ]; } ''
          import os
          import time
          import requests
          import subprocess

          THRESHOLD = ${toString config.modules.services.hass.solarLightThreshold}
          REFRESH_RATE = 60
          COOLDOWN_PERIOD = 5 * 60


          def get_entity_status(entity_id):
              url = f"${hassIntegration.endpoint}/api/states/{entity_id}"
              headers = {
                  "Authorization": f"Bearer {token}",
                  "Content-Type": "application/json",
              }
              response = requests.get(url, headers=headers)

              if response.status_code == 200:
                  entity_data = response.json()
                  return entity_data
              else:
                  print(f"Failed to retrieve entity status: {response.status_code}")
                  return None


          def check_power():
              status = get_entity_status("sensor.powerwall_solar_power")
              if status:
                  power = float(status['state'])
                  if power < THRESHOLD and current_mode != "dark":
                      switch_mode("dark")
                  elif power >= THRESHOLD and current_mode != "light":
                      switch_mode("light")


          def switch_mode(mode):
              global current_mode, last_switch_time

              if (time.time() - last_switch_time < COOLDOWN_PERIOD):
                  print("Skipping theme switching due to cooldown")
                  return

              print(f"Switching to mode {mode}")
              current_mode = mode
              last_switch_time = time.time()
              os.system(f"darkman set {mode}")


          if __name__ == "__main__":
              global token, current_mode

              token_path = os.path.expandvars('${hassToken.path}')
              with open(token_path, 'r') as file:
                  token = file.read().rstrip()
              current_mode = subprocess.getoutput("darkman get")

              while True:
                  check_power()
                  time.sleep(REFRESH_RATE)
        '';
      };

      Install.WantedBy = [ "darkman.service" ];
    };

  } // colorSchemeSwitchingConfiguration);
}
