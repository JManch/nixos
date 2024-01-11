lib:
let
  inherit (lib) mkMerge mkIf;
in
{
  mkIfElse = p: yes: no: mkMerge [
    (mkIf p yes)
    (mkIf (!p) no)
  ];

  homeConfig = args: args.outputs.nixosConfigurations.${args.hostname}.config.home-manager.users.${args.username};
}
