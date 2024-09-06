lib: ns:
let
  inherit (lib)
    attrNames
    filterAttrs
    imap0
    hasAttr
    elem
    genAttrs
    head
    findFirst
    optionalString
    tail
    concatStrings
    toUpper
    mod
    elemAt
    concatMap
    stringToCharacters
    singleton
    nixosSystem
    optionals
    hasPrefix
    hasSuffix
    ;
in
{
  ${ns} = {
    mkHost = self: hostname: username: system: {
      name = hostname;
      value = nixosSystem {
        specialArgs = {
          inherit
            self
            hostname
            username
            lib
            ns
            ;
          inherit (self) inputs;
          selfPkgs = self.packages.${system};
          pkgs' = import self.inputs.nixpkgs-small {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules =
          [
            {
              nixpkgs.hostPlatform = system;
              nixpkgs.buildPlatform = "x86_64-linux";
            }
            ../hosts/${hostname}
            ../modules/nixos
          ]
          ++ optionals (hasPrefix "pi" hostname) [
            # Raspberry-pi-nix does not have an enable option so we have to
            # conditionally import like this
            self.inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            ../modules/nixos/hardware/raspberry-pi.nix
          ];
      };
    };

    forEachSystem =
      self: systems: f:
      genAttrs systems (
        system:
        f (
          import self.inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          }
        )
      );

    # We use an unorthodox pkgs reference here because pkgs will not be in the
    # first layer of arguments if it is not explicitly added to the module
    # parameters. This is annoying because the LSP complains about pkgs being an
    # unused argument when it actually is used. This method avoids that.
    flakePkgs =
      args: flake: args.inputs.${flake}.packages.${args.options._module.args.value.pkgs.stdenv.system};

    addPatches =
      pkg: patches:
      pkg.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ patches;
      });

    upperFirstChar =
      string:
      let
        chars = stringToCharacters string;
      in
      concatStrings ([ (toUpper (head chars)) ] ++ (tail chars));

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
        inherit (osConfig.${ns}.device) monitors;
      in
      findFirst (m: m.number == number) (head monitors) monitors;

    getMonitorHyprlandCfgStr =
      m:
      "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${toString m.position.x}x${toString m.position.y},1,transform,${toString m.transform}${
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

    waylandWindowManagers = [ "hyprland" ];

    waylandDesktopEnvironments = [ "gnome" ];

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
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProcSubset = "pid";
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
        SocketBindDeny = config.${ns}.system.networking.publicPorts;
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
          config.home-manager.users.${config.${ns}.core.username or ""}.${ns} or config.${ns} or null;
      in
      (modules.desktop.enable or false) && modules.desktop.windowManager == "hyprland";
  };
}
