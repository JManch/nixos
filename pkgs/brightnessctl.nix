{
  brightnessctl,
  pkg-config,
  sources,
}:
brightnessctl.overrideAttrs {
  version = "0-unstable-${sources.brightnessctl.revision}";
  src = sources.brightnessctl;

  nativeBuildInputs = [ pkg-config ];
  postPatch = "";

  preBuild = ''
    ./configure --dbus-provider=systemd
  '';

  makeFlags = [
    "PREFIX="
    "DESTDIR=$(out)"
  ];
}
