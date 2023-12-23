{pkgs, ...}: {
  hardware.opengl = {
    enable = true;

    # Enable for 32bit wine
    driSupport32Bit = false;
    extraPackages = with pkgs; [
      vaapiVdpau
    ];
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Major issues if this is disabled
    modesetting.enable = true;

    open = true;

    # Doesn't work on wayland
    nvidiaSettings = false;
  };
}
