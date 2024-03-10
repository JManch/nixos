# Copyright (c) 2003-2024 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ctrld;
  settingsFormat = pkgs.formats.toml { };
in
{

  options.services.ctrld = {
    enable = mkEnableOption "ctrld, a highly configurable DNS forwarding proxy";

    package = mkPackageOption pkgs "ctrld" { };

    settings = mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        Configuration for ctrld, see
        <https://github.com/Control-D-Inc/ctrld/blob/main/docs/config.md>
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.ctrld = {
      unitConfig = {
        Description = "Multiclient DNS forwarding proxy";
        Before = [ "nss-lookup.target" ];
        After = [ "network.target" "network-online.target" ];
        Wants = [ "network-online.target" "nss-lookup.target" ];
        StartLimitIntervalSec = 5;
        StartLimitBurst = 10;
      };

      serviceConfig = {
        ExecStart = "${getExe cfg.package} run --config ${settingsFormat.generate "ctrld.toml" cfg.settings}";
        Restart = "always";
        RestartSec = 10;

        # WARN: DynamicUser breaks the ctrld 'controlServer' because ctrld
        # tries to write a socket file to /var/run. The 'controlServer'
        # provides the ctrld start, stop, reload etc... commands. Since we are
        # running ctrld in a systemd service we don't need these anyway and
        # would prefer the extra security.
        DynamicUser = true;
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
