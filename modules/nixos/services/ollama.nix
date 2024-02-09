{ lib
, pkgs
, config
, inputs
, ...
}:
let
  cfg = config.modules.services.ollama;
in
lib.mkIf cfg.enable
{
  services.ollama = {
    enable = true;
    package = inputs.ollama.packages.${pkgs.system}.rocm;
  };
  systemd.services.ollama = {
    wantedBy = lib.mkForce (lib.lists.optional cfg.autoStart [ "multi-user.target" ]);
  };
  environment.systemPackages = [ pkgs.oterm ];

  environment.persistence."/persist".directories = [
    # Can't actually be defined because it's a DynamicUser service.
    # /var/lib/private is persisted instead.
    # "/var/lib/private/ollama"
  ];
}
