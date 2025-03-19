{
  lib,
  buildHomeAssistantComponent,
  sources,
  ...
}:
buildHomeAssistantComponent rec {
  owner = "dolezsa";
  domain = "thermal_comfort";
  inherit (sources.thermal_comfort) version;
  src = sources.thermal_comfort;

  dontBuild = true;

  meta = {
    changelog = "https://github.com/dolezsa/thermal_comfort/releases/tag/v${version}";
    description = "Thermal Comfort sensor for HA";
    homepage = "https://github.com/dolezsa/thermal_comfort";
    license = lib.licenses.mit;
  };
}
