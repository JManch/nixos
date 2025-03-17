{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  runtimeShell,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "app2unit";
  version = "0-unstable-2025-3-17";

  src = fetchFromGitHub {
    owner = "Vladimir-csp";
    repo = "app2unit";
    rev = "0900cb6bce30122b8db5a1292e8fc2b14c1732ec";
    hash = "sha256-1sQs9g9fzghC60Hl7oHH6F0uDmzNuNwDAz92THQGmt8=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace app2unit \
      --replace-fail "/bin/sh" "${runtimeShell}"
  '';

  installPhase = ''
    runHook preInstall

    install -Dt $out/bin app2unit
    makeWrapper $out/bin/app2unit $out/bin/app2unit-open \
      --add-flags "--open"

    runHook postInstall
  '';

  meta = {
    description = "Launches Desktop Entries as Systemd user units";
    homepage = "https://github.com/Vladimir-csp/app2unit";
    mainProgram = "app2unit";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ JManch ];
    platforms = lib.platforms.linux;
  };
}
