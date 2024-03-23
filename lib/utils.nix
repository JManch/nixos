lib:
let
  inherit (lib) attrNames filterAttrs;
in
{
  homeConfig = args:
    args.outputs.nixosConfigurations.${args.hostname}.config.home-manager.users.${args.username};

  flakePkgs = args: flake: args.inputs.${flake}.packages.${args.pkgs.system};

  addPatches = pkg: patches: pkg.overrideAttrs
    (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ patches;
    });

  hosts = outputs: filterAttrs (host: v: (host != "installer")) outputs.nixosConfigurations;

  hardeningBaseline = config: overrides: {
    DynamicUser = true;
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateUsers = true; # this has to be false for CAP_NET_BIND_SERVICE
    PrivateDevices = true;
    PrivateMounts = true;
    PrivateTmp = true;
    ProtectSystem = "strict"; # this does not apply to service directories like StateDirectory
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
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    # SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    DeviceAllow = "";
    SocketBindDeny = config.modules.system.networking.publicPorts;
    SocketBindAllow = "all";
    MemoryDenyWriteExecute = true;
    UMask = "0077";
  } // overrides;

  # Get list of all nix files and directories in path for easy importing
  scanPaths = path:
    map (f: (path + "/${f}"))
      (attrNames
        (filterAttrs
          (path: _type:
            (_type == "directory") || (
              (path != "default.nix")
              && (lib.strings.hasSuffix ".nix" path)
            )
          )
          (builtins.readDir path)));
}
