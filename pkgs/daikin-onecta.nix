{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "jwillemsen";
  domain = "daikin_onecta";
  version = "4.1.16";

  src = fetchFromGitHub {
    owner = "jwillemsen";
    repo = "daikin_onecta";
    rev = "refs/tags/v${version}";
    hash = "sha256-XKXAUlMfPQbVzEW4wJrfY5jZcg+B3qYMItwV/h0qqYM=";
  };

  meta = {
    description = "Home Assistant Integration for devices supported by the Daikin Onecta App";
    homepage = "https://github.com/jwillemsen/daikin_onecta";
    license = lib.licenses.mit;
  };
}
