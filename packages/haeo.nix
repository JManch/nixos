{
  lib,
  home-assistant,
  sources,
}:
home-assistant.python.pkgs.callPackage (
  {
    buildHomeAssistantComponent,
    highspy,
    numpy,
    ...
  }:
  buildHomeAssistantComponent {
    owner = "hass-energy";
    domain = "haeo";
    inherit (sources.haeo) version;
    src = sources.haeo;

    dependencies = [
      highspy
      numpy
    ];

    meta = {
      description = "Home Assistant energy optimiser";
      homepage = "https://github.com/hass-energy/haeo";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ JManch ];
    };
  }
) { }
