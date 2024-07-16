{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "dolezsa";
  domain = "thermal_comfort";
  version = "2.2.2";

  src = fetchFromGitHub {
    inherit owner;
    repo = domain;
    rev = "refs/tags/${version}";
    hash = "sha256-L6Oamy7WoWypCPFxpZa45XbMVmB4LF0qYdB0oJF/TOI=";
  };

  dontBuild = true;

  meta = {
    changelog = "https://github.com/dolezsa/thermal_comfort/releases/tag/v${version}";
    description = "Thermal Comfort sensor for HA";
    homepage = "https://github.com/dolezsa/thermal_comfort";
    license = lib.licenses.mit;
  };
}
