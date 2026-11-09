{
  allAddresses,
  config,
  ...
}:

let
  port = allAddresses.hosts.${config.networking.hostName}.services.weather.port;
in
{
  virtualisation.oci-containers.containers.weather = {
    image = "ghcr.io/mwood77/ws4kp-international:latest";
    ports = [ "127.0.0.1:${toString port}:8080" ];
    environment.WS4KP_PORT = "8080";
  };
}
