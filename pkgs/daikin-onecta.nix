{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "jwillemsen";
  domain = "daikin_onecta";
  version = "4.1.15";

  src = fetchFromGitHub {
    owner = "jwillemsen";
    repo = "daikin_onecta";
    rev = "refs/tags/v${version}";
    hash = "sha256-kojIn/ElyI3poU3Lpl6qtPE8ACh7fsn6//5hBAz4s4s=";
  };

  meta = {
    description = "Home Assistant Integration for devices supported by the Daikin Onecta App";
    homepage = "https://github.com/jwillemsen/daikin_onecta";
    license = lib.licenses.mit;
  };
}
