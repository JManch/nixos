{
  lib,
  pkgs,
  config,
}:
{
  home.packages = [
    (pkgs.writeShellScriptBin "qobuz-dl" ''
      export HOME="${config.age.secretsDir}/qobuz-dl-home"
      ${lib.getExe pkgs.${lib.ns}.qobuz-dl} "$@"
    '')
  ];
}
