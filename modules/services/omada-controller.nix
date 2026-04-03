_:

{
  virtualisation.oci-containers.containers.omada-controller = {
    image = "mbentley/omada-controller:latest";
    autoStart = true;
    environment = {
      TZ = "America/Sao_Paulo";
      MANAGE_HTTP_PORT = "8088";
      MANAGE_HTTPS_PORT = "8043";
      PORTAL_HTTP_PORT = "8084";
      PORTAL_HTTPS_PORT = "8843";
      SHOW_SERVER_JS_WARNING = "false";
      SHOW_MONGODB_RAM_WARNING = "false";
    };
    ports = [
      "8088:8088/tcp"
      "8043:8043/tcp"
      "8843:8843/tcp"
      "29810:29810/udp"
      "29811:29811/tcp"
      "29812:29812/tcp"
      "29813:29813/tcp"
      "29814:29814/tcp"
    ];
    volumes = [
      "/var/lib/omada/data:/opt/tplink/EAPController/data"
      "/var/lib/omada/logs:/opt/tplink/EAPController/logs"
    ];
  };

  # Omada SDN Controller firewall rules
  networking.firewall.allowedTCPPorts = [
    8088
    8043
    8843
    29811
    29812
    29813
    29814
  ];
  networking.firewall.allowedUDPPorts = [ 29810 ];
}
