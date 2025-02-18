{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "dolezsa";
  domain = "thermal_comfort";
  version = "2.2.4";

  src = fetchFromGitHub {
    inherit owner;
    repo = domain;
    tag = version;
    hash = "sha256-YpXHek8IFFOv4ojKvlF9g8iAffCBUtmk+Ahj3DsT0PM=";
  };

  dontBuild = true;

  meta = {
    changelog = "https://github.com/dolezsa/thermal_comfort/releases/tag/v${version}";
    description = "Thermal Comfort sensor for HA";
    homepage = "https://github.com/dolezsa/thermal_comfort";
    license = lib.licenses.mit;
  };
}
