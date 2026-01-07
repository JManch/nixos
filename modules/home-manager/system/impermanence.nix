{ lib }:
{
  imports = [
    (lib.mkAliasOptionModule [ lib.ns "persistence" ] [ "home" "persistence" "/persist" ])
  ];
}
