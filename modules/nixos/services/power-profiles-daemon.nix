{ config }:
{
  enableOpt = false;
  conditions = [ config.services.power-profiles-daemon.enable ];
  ns.persistence.directories = [ "/var/lib/power-profiles-daemon" ];
}
