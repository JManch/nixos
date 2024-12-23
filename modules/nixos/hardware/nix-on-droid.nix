# Install steps:
# - install private github key and host key into ~/.ssh
# - nix shell nixpkgs#gitMinimal nixpkgs#openssh
# - nix-on-droid switch --flake github:JManch/nixos#<hostname>
{
  lib,
  pkgs,
  config,
  inputs,
  hostname,
  ...
}@args:
let
  inherit (lib)
    ns
    mkIf
    types
    mkOption
    getExe
    getExe'
    optional
    mkEnableOption
    ;
  inherit (config.user) home;
  cfg = config.${ns}.nix-on-droid;
  sshdConf = "${home}/.config/sshd_config";
in
{
  options.${ns}.nix-on-droid = {
    uid = mkOption {
      type = types.int;
      description = ''
        UID of the nix-on-droid user on the Android device. To find run `id
        nix-on-droid` in the app.
      '';
    };

    gid = mkOption {
      type = types.int;
      description = "GID of the nix-on-droid user device";
    };

    ssh.server = {
      enable = mkEnableOption "SSHD server";

      authorizedKeys = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = "List of authorized SSH keys for the default user";
      };
    };
  };

  config = {
    environment.motd = null;
    _module.args.username = config.user.userName;
    time.timeZone = "Europe/London";
    nix.extraOptions = "experimental-features = nix-command flakes";
    nix.registry.n.flake = inputs.nixpkgs;

    environment.packages =
      (with pkgs; [
        openssh
        git
      ])
      ++ optional cfg.ssh.server.enable (
        pkgs.writeScriptBin "sshd-start" ''
          ${getExe' pkgs.openssh "sshd"} -f "${sshdConf}" -D
        ''
      );

    build.activation = mkIf cfg.ssh.server.enable {
      sshd-setup = ''
        $DRY_RUN_CMD mkdir $VERBOSE_ARG -p "${home}/.ssh"
        $DRY_RUN_CMD rm $VERBOSE_ARG -f "${home}/.ssh/authorized_keys"
        ${lib.concatMapStringsSep "\n" (
          key: "$DRY_RUN_CMD echo \"${key}\" >> \"${home}/.ssh/authorized_keys\""
        ) cfg.ssh.server.authorizedKeys}
        $DRY_RUN_CMD rm $VERBOSE_ARG -f "${sshdConf}"
        $DRY_RUN_CMD echo -e "HostKey ${home}/.ssh/ssh_host_ed25519_key\nPort 8022\nAllowUsers nix-on-droid\nPasswordAuthentication No\nKbdInteractiveAuthentication No\n" > "${sshdConf}"
      '';
    };

    user = {
      uid = cfg.uid;
      gid = cfg.gid;
      shell = "${getExe pkgs.zsh}";
    };

    terminal = {
      font = "${
        (lib.${ns}.flakePkgs args "nix-resources").berkeley-mono-nerdfont
      }/share/fonts/truetype/NerdFonts/BerkeleyMonoNerdFont-Regular.ttf";

      colors = with config.home-manager.config.colorScheme.palette; {
        background = "#${base00}";
        foreground = "#${base05}";
        color0 = "#${base03}";
        color1 = "#${base08}";
        color2 = "#${base0B}";
        color3 = "#${base0A}";
        color4 = "#${base0D}";
        color5 = "#${base0E}";
        color6 = "#${base0C}";
        color7 = "#${base04}";
        color8 = "#${base03}";
        color9 = "#${base08}";
        color10 = "#${base0B}";
        color11 = "#${base0A}";
        color12 = "#${base0D}";
        color13 = "#${base0E}";
        color14 = "#${base0C}";
        color15 = "#${base03}";
      };
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      config = ../../../homes/${hostname}.nix;
      sharedModules = [ ../../../modules/home-manager ];
      extraSpecialArgs = {
        inherit (args)
          ns
          inputs
          self
          username
          hostname
          ;
      };
    };
  };
}
