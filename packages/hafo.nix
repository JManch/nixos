{
  lib,
  buildHomeAssistantComponent,
  sources,
}:
buildHomeAssistantComponent {
  owner = "hass-energy";
  domain = "hafo";
  inherit (sources.hafo) version;
  src = sources.hafo;

  meta = {
    description = "Home Assistant entity forecast";
    homepage = "https://github.com/hass-energy/hafo";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ JManch ];
  };
}
