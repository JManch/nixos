lib:
let
  inherit (lib) mkMerge mkIf;
in
{
  mkIfElse = p: yes: no: mkMerge [
    (mkIf p yes)
    (mkIf (!p) no)
  ];
}
