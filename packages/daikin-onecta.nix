{ home-assistant, sources }:
home-assistant.python3Packages.callPackage (
  {
    lib,
    buildHomeAssistantComponent,
    buildPythonPackage,
    setuptools,
    aiohttp,
    mashumaro,
    ...
  }:
  let
    daikin-onecta = buildPythonPackage {
      pname = "daikin-onecta";
      inherit (sources.daikin-onecta) version;
      src = sources.daikin-onecta;
      pyproject = true;
      build-system = [ setuptools ];
      dependencies = [
        aiohttp
        mashumaro
      ];
    };
  in
  buildHomeAssistantComponent {
    owner = "jwillemsen";
    domain = "daikin_onecta";
    inherit (sources.daikin_onecta) version;
    src = sources.daikin_onecta;

    dependencies = [ daikin-onecta ];

    meta = {
      description = "Home Assistant Integration for devices supported by the Daikin Onecta App";
      homepage = "https://github.com/jwillemsen/daikin_onecta";
      license = lib.licenses.mit;
    };
  }
) { }
