{
  lib,
  stdenvNoCC,
  sources,
  dash,
  installShellFiles,
}:
stdenvNoCC.mkDerivation {
  pname = "app2unit";
  version = "0-unstable-${sources.app2unit.revision}";
  src = sources.app2unit;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    installBin app2unit
    ln -s $out/bin/app2unit $out/bin/app2unit-open
  '';

  dontPatchShebangs = true;
  postFixup = ''
    substituteInPlace $out/bin/app2unit \
      --replace-fail '#!/bin/sh' '#!${lib.getExe dash}'
  '';

  meta = {
    description = "Launches Desktop Entries as Systemd user units";
    homepage = "https://github.com/Vladimir-csp/app2unit";
    mainProgram = "app2unit";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}
