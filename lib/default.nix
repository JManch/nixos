self: lib: ns:
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
  sources = import ../pkgs/npins;
in
{
  inherit ns;
  ${ns} = (import ./module-wrapper.nix lib ns) // {
    mkHost = hostname: username: system: {
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
          selfPkgs = self.packages.${system};
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
          # Raspberry-pi-nix does not have an enable option so we have to
          # conditionally import like this
          ++ optionals (hasPrefix "pi" hostname) [
            ../modules/nixos/hardware/raspberry-pi.nix
          ];
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
              overlays = [ nix-on-droid.overlays.default ];
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
            selfPkgs = self.packages.${system};
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
            config.allowUnfree = true;
          }
        )
      );

    # We use an unorthodox pkgs reference here because pkgs will not be in the
    # first layer of arguments if it is not explicitly added to the module
    # parameters.
    flakePkgs =
      args: flake: args.inputs.${flake}.packages.${args.options._module.args.value.pkgs.system};

    addPatches =
      pkg: patches:
      pkg.overrideAttrs (oldAttrs: {
        patches =
          (oldAttrs.patches or [ ]) ++ (map (p: if hasPrefix "/" p then p else ../patches + "/${p}") patches);
      });

    hostIp = hostname: self.nixosConfigurations.${hostname}.config.${ns}.core.device.ipAddress;

    upperFirstChar =
      string: concatStrings (imap0 (i: c: if i == 0 then toUpper c else c) (stringToCharacters string));

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

    sshAddQuiet =
      args: # bash
      let
        ssh-add = args.lib.getExe' args.options._module.args.value.pkgs.openssh "ssh-add";
      in
      ''
        if [[ "$(${ssh-add} -l)" == "The agent has no identities." ]]; then
          ${ssh-add}
        fi
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
  };
}
