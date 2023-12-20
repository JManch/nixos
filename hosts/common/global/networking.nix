{
  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = true;
    };
    firewall = {
      enable = true;
    };
  };

  boot.kernel.sysctl = {
    ## TCP optimization
    # TCP Fast Open is a TCP extension that reduces network latency by packing
    # data in the sender’s initial TCP SYN. Setting 3 = enable TCP Fast Open for
    # both incoming and outgoing connections:
    "net.ipv4.tcp_fastopen" = 3;
    # Bufferbloat mitigations + slight improvement in throughput & latency
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "cake";
  };

  services.resolved = {
    enable = true;
    fallbackDns = [ ];
  };
}
