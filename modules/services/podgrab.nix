{
  config,
  allAddresses,
  ...
}:

let
  addrs = allAddresses.hosts.${config.networking.hostName};
in
{
  virtualisation.oci-containers.containers.podgrab = {
    image = "docker.io/akhilrex/podgrab:latest";
    ports = [ "${toString addrs.services.podgrab.port}:8080" ];
    volumes = [
      "/var/lib/container-volumes/podgrab:/config"
      "/persist/media/podcasts:/assets"
    ];
    environment = {
      CHECK_FREQUENCY = "60";
    };
    extraOptions = [
      "--umask=0002"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/container-volumes/podgrab 0755 root root - -"
    "d /persist/media/podcasts 2775 root media - -"
  ];
}
