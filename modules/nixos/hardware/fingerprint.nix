# Setup: `sudo fprintd-enroll <username>`
{ lib, config }:
{
  enableOpt = false;
  conditions = [ config.services.fprintd.enable ];

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/fprint";
    mode = "0700";
  };
}
