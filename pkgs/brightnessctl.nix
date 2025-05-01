{
  brightnessctl,
  coreutils,
  sources,
}:
brightnessctl.overrideAttrs {
  version = "0-unstable-${sources.brightnessctl.revision}";
  src = sources.brightnessctl;

  postPatch = ''
    substituteInPlace 90-brightnessctl.rules \
      --replace-fail /bin/ ${coreutils}/bin/
  '';

  preBuild = ''
    ./configure --dbus-provider=systemd --enable-logind
  '';

  makeFlags = [
    "PREFIX="
    "DESTDIR=$(out)"
  ];
}
