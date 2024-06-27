lib:
let
  inherit (lib)
    attrNames
    filterAttrs
    imap0
    head
    tail
    concatStrings
    toUpper
    mod
    elemAt
    concatMap
    hasPrefix
    stringToCharacters;
in
{
  # We use an unorthodox pkgs reference here because pkgs will not be in the
  # first layer of arguments if it is not explicitly added to the module
  # parameters. This is annoying because the LSP complains about pkgs being an
  # unused argument when it actually is used. This method avoids that.
  flakePkgs = args: flake: args.inputs.${flake}.packages.${args.options._module.args.value.pkgs.system};

  addPatches = pkg: patches: pkg.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ patches;
  });

  hosts = self: filterAttrs (host: _: !hasPrefix "installer" host) self.nixosConfigurations;

  upperFirstChar = string:
    let
      chars = stringToCharacters string;
    in
    concatStrings ([ (toUpper (head chars)) ] ++ (tail chars));

  # Adding multiple EXIT traps in a bash script is a pain because they
  # overwrite each other. This makes that easier.
  exitTrapBuilder = /*bash*/ ''
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
