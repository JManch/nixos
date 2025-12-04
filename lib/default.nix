self: lib: ns:
let
  inherit (lib)
    attrNames
    filterAttrs
    imap0
    pathExists
    optional
    hasAttr
    elem
    getExe
    getExe'
    genAttrs
    head
    findFirst
    optionalString
    mod
    elemAt
    concatMap
    singleton
    nixosSystem
    optionals
    hasPrefix
    hasSuffix
    mkBefore
    assertMsg
    ;
  sources = import ../npins;
in
{
  inherit ns;
  ${ns} = (import ./module-wrapper.nix lib ns) // {
    mkHost = hostname: username: system: extraModules: {
      name = hostname;
      value = nixosSystem {
        specialArgs = {
          inherit (self) inputs;
          inherit
            self
            hostname
            username
            sources
            ;
        };
        modules = [
          {
            nixpkgs.hostPlatform = system;
            nixpkgs.buildPlatform = "x86_64-linux";
            nixpkgs.overlays = mkBefore [ (_: prev: { ${ns} = import ../pkgs self lib prev; }) ];
          }
          ../modules/nixos
        ]
        ++ optional (pathExists ../hosts/${hostname}) ../hosts/${hostname}
        # Raspberry-pi-nix does not have an enable option so we have to
        # conditionally import like this
        ++ optionals (hasPrefix "pi" hostname) [
          ../modules/nixos/hardware/raspberry-pi.nix
        ]
        ++ extraModules;
      };
    };

    mkDroidHost = hostname: {
      name = hostname;
      value =
        let
          inherit (self.inputs) nixpkgs nix-on-droid;
          system = "aarch64-linux";
        in
        nix-on-droid.lib.nixOnDroidConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              overlays = mkBefore [
                (_: prev: { ${ns} = import ../pkgs self lib prev; })
                nix-on-droid.overlays.default
              ];
            };
          };
          modules = [
            ../hosts/${hostname}
            ../modules/nixos/hardware/nix-on-droid.nix
          ];
          extraSpecialArgs = {
            inherit (self) inputs;
            inherit
              lib
              self
              hostname
              sources
              ;
          };
        };
    };

    forEachSystem =
      f:
      genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        f (
          import self.inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              overlays = [ (_: prev: { ${ns} = import ../pkgs self lib prev; }) ];
            };
          }
        )
      );

    # We use an unorthodox pkgs reference here because pkgs will not be in the
    # first layer of arguments if it is not explicitly added to the module
    # parameters.
    flakePkgs =
      args: flake:
      args.inputs.${flake}.packages.${args.options._module.args.value.pkgs.stdenv.hostPlatform.system};

    addPatches =
      pkg: patches:
      pkg.overrideAttrs (oldAttrs: {
        patches =
          (oldAttrs.patches or [ ]) ++ (map (p: if hasPrefix "/" p then p else ../patches + "/${p}") patches);
      });

    hostIp = hostname: self.nixosConfigurations.${hostname}.config.${ns}.core.device.address;
    hostVPNIp = hostname: self.nixosConfigurations.${hostname}.config.${ns}.core.device.vpnAddress;
    hostIps =
      hostname:
      let
        inherit (self.nixosConfigurations.${hostname}.config.${ns}.core.device)
          address
          altAddresses
          vpnAddress
          ;
      in
      optional (address != null) address ++ optional (vpnAddress != null) vpnAddress ++ altAddresses;

    # Adding multiple EXIT traps in a bash script is a pain because they
    # overwrite each other. This makes that easier.
    exitTrapBuilder = # bash
      ''
        exit_trap_command=""
        function call_exit_traps {
          eval "$exit_trap_command"
        }
        trap call_exit_traps EXIT

        function add_exit_trap {
          local to_add=$1
          if [ -z "$exit_trap_command" ]; then
            exit_trap_command="$to_add"
          else
            exit_trap_command="$exit_trap_command; $to_add"
          fi
        }
      '';

    getMonitorByNumber =
      osConfig: number:
      let
        inherit (osConfig.${ns}.core.device) monitors;
      in
      findFirst (m: m.number == number) (head monitors) monitors;

    getMonitorByName =
      osConfig: name:
      let
        inherit (osConfig.${ns}.core.device) monitors;
      in
      findFirst (m: m.name == name) (head monitors) monitors;

    getMonitorHyprlandCfgStr =
      m:
      "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${toString m.position.x}x${toString m.position.y},${toString m.scale},transform,${toString m.transform}${
        optionalString (m.mirror != null) ",mirror,${m.mirror}"
      }";

    asserts =
      asserts:
      concatMap (a: a) (
        imap0 (
          i: elem:
          if (mod i 2) == 0 then
            singleton {
              assertion = elem;
              message = (elemAt asserts (i + 1));
            }
          else
            [ ]
        ) asserts
      );

    wgInterfaceEnabled =
      interface: osConfig:
      (hasAttr interface (osConfig.${ns}.services.wireguard or { }))
      && (osConfig.${ns}.services.wireguard.${interface}.enable);

    hardeningBaseline =
      config: overrides:
      {
        DynamicUser = true;
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateUsers = true; # has to be false for CAP_NET_BIND_SERVICE
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        ProtectSystem = "strict"; # does not apply to service directories like StateDirectory
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        DeviceAllow = "";
        MemoryDenyWriteExecute = true;
        UMask = "0077";
      }
      // overrides;

    # Get list of all nix files and directories in path for easy importing
    scanPaths =
      path:
      map (f: (path + "/${f}")) (
        attrNames (
          filterAttrs (
            path: _type: (_type == "directory") || ((path != "default.nix") && (hasSuffix ".nix" path))
          ) (builtins.readDir path)
        )
      );

    scanPathsExcept =
      path: except:
      map (f: (path + "/${f}")) (
        attrNames (
          filterAttrs (
            path: _type:
            (_type == "directory")
            || ((!elem path except) && (path != "default.nix") && (hasSuffix ".nix" path))
          ) (builtins.readDir path)
        )
      );

    isHyprland =
      config:
      let
        modules =
          config.home-manager.users.${config.${ns}.core.users.username or ""}.${ns} or config.${ns} or null;
      in
      (modules.desktop.enable or false) && modules.desktop.windowManager == "hyprland";

    sliceSuffix =
      config:
      assert
        (!config ? home.stateVersion)
        || throw "Slice suffix should be passed osConfig not Home Manager config";
      optionalString (config.programs.uwsm.enable or false) "-graphical";

    # For applications that only allow a single instance to be open
    wrapHyprlandMoveToActive =
      args: package: class: extra:
      let
        inherit (args.options._module.args.value) pkgs;
        isHyprland = lib.${ns}.isHyprland args.config;
      in
      if !isHyprland && extra == "" then
        package
      else
        pkgs.symlinkJoin {
          name = "${package.name}-hyprland-move-to-active";
          paths = [ package ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/${package.meta.mainProgram} --run '
              ${optionalString isHyprland ''
                address=$(${getExe' pkgs.hyprland "hyprctl"} clients -j | ${getExe pkgs.jaq} -r "(.[] | select(.class == \"${class}\")) | .address")
                if [[ -n $address ]]; then
                  ${getExe' pkgs.hyprland "hyprctl"} dispatch movetoworkspacesilent e+0, address:"$address"
                  exit 0
                fi
              ''}
            ' ${extra}
          '';
        };

    wrapAlacrittyOpaque =
      args: package:
      let
        inherit (args.options._module.args.value) pkgs;
      in
      if
        args.config.programs.alacritty.enable or args.config.${args.lib.ns}.hm.programs.alacritty.enable
      then
        (pkgs.symlinkJoin {
          name = "${package.name}-alacritty-opaque";
          paths = [ package ];
          postBuild = ''
            ln -fs ${pkgs.writeShellScript "${package.name}-alacritty-opaque-wrapped" ''
              if [[ -z $DISPLAY && -z $WAYLAND_DISPLAY ]] || [[ $TERM != "alacritty" ]]; then
                exec ${getExe package} "$@"
              fi

              reset() {
                ${getExe pkgs.alacritty} msg config --reset
              }
              trap reset EXIT

              ${getExe pkgs.alacritty} msg config window.opacity=1
              ${getExe package} "$@"
            ''} $out/bin/${package.meta.mainProgram}
          '';
        })
      else
        package;

    revDisableCondition =
      name: rev:
      assert assertMsg (self.inputs.nixpkgs.rev == rev) "Module ${name} can be re-enabled";
      false;

    mkHyprlandCenterFloatRule = class: widthPercentage: heightPercentage: {
      matchers.class = class;
      params = {
        float = true;
        size = "(monitor_w*${toString widthPercentage}/100) (monitor_h*${toString heightPercentage}/100)";
        center = true;
      };
    };

    throttleHyprlandRepeatBind =
      name: targetRepeatRate:
      # bash
      ''
        # Use /dev/shm to ensure that it'll use tmpfs
        throttle_timestamp="/dev/shm/hypr-throttle-${name}"
        throttle_current_time=$(date +%s%N)
        throttle_last_time=$(<"$throttle_timestamp") 2>/dev/null || throttle_last_time=0
        throttle_diff=$((throttle_current_time - throttle_last_time))
        [[ $throttle_diff -lt ${toString (1000000000 / targetRepeatRate)} ]] && exit 0
        echo "$throttle_current_time" > "$throttle_timestamp"
      '';

    impermanencePrefix =
      config: path:
      assert assertMsg (
        !hasPrefix "/persist" path
      ) "Path '${path}' was manually prefixed with /persist, this is not allowed";
      (optionalString config.${ns}.system.impermanence.enable "/persist") + path;
  };
}
