{
  pkgs,
  username,
  ...
}: {
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    pulse.enable = true;
  };

  hardware.pulseaudio.enable = false;

  # Reduces latency
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    easyeffects
    helvum
  ];

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".config/easyeffects"
    ];
  };
}
