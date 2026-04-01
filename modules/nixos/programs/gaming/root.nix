{
  # This guards home-manager gaming config in
  # modules/home-manager/programs/desktop.gaming/root.nix
  enableOpt = true;

  boot.kernelModules = [ "ntsync" ];
}
