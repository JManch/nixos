{ lib, config }:
{
  conditions = [ config.services.fprintd.enable ];

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/fprint";
    mode = "0700";
  };
}
