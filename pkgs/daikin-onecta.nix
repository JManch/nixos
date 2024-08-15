{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "jwillemsen";
  domain = "daikin_onecta";
  version = "4.1.14";

  src = fetchFromGitHub {
    owner = "jwillemsen";
    repo = "daikin_onecta";
    rev = "refs/tags/v${version}";
    hash = "sha256-mtaDoK2siOug/5KCAiyYFV3GPcdEw6+5gP3pt+b7lbI=";
  };

  meta = {
    description = "Home Assistant Integration for devices supported by the Daikin Onecta App";
    homepage = "https://github.com/jwillemsen/daikin_onecta";
    license = lib.licenses.mit;
  };
}
