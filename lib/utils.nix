lib:
let
  inherit (lib) attrNames filterAttrs imap0 mod elemAt concatMap;
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

  asserts = asserts:
    concatMap (a: a) (
      imap0
        (
          i: elem:
            if (mod i 2) == 0 then
              [{ assertion = elem; message = (elemAt asserts (i + 1)); }] else [ ]
        )
        asserts);

  hardeningBaseline = config: overrides: {
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
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    DeviceAllow = "";
    SocketBindDeny = config.modules.system.networking.publicPorts;
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
