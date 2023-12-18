{
  security.rtkit.enable = true;
  hardware.pulseaudio.enable =  false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    pulse.enable = true;
  };
}
