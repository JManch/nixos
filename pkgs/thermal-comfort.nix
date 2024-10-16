{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "dolezsa";
  domain = "thermal_comfort";
  version = "2.2.3";

  src = fetchFromGitHub {
    inherit owner;
    repo = domain;
    rev = "refs/tags/${version}";
    hash = "sha256-x/3xy7lwKTM6LUL1xnT/u2H5p18zBD8NsLXTjw1WmuY=";
  };

  dontBuild = true;

  meta = {
    changelog = "https://github.com/dolezsa/thermal_comfort/releases/tag/v${version}";
    description = "Thermal Comfort sensor for HA";
    homepage = "https://github.com/dolezsa/thermal_comfort";
    license = lib.licenses.mit;
  };
}
