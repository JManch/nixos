{
  lib,
  stdenvNoCC,
  sources,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "thermal-comfort-icons";
  inherit (sources.thermal_comfort_icons) version;
  src = sources.thermal_comfort_icons;

  dontBuild = true;

  installPhase = ''
    install -D -m 755 dist/thermal_comfort_icons.js "$out"
  '';

  meta = with lib; {
    homepage = "https://github.com/rautesamtr/thermal_comfort_icons";
    description = "Thermal Comfort custom icons for Home Assistant";
    license = with licenses; [
      mit
      asl20
    ];
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
