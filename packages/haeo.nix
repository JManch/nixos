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
    # inherit (sources.haeo) version;
    version =
      assert lib.assertMsg (
        sources.haeo.revision == "92e687fa9cfedc5f70c8d7d65fd5e9ef18a830f7"
      ) "remove haeo override";
      "v0.4.0rc8";
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
