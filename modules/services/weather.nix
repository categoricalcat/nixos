{
  allAddresses,
  config,
  ...
}:

let
  port = allAddresses.hosts.${config.networking.hostName}.services.weather.port;
in
{
  # Stateless static server: one account with its own group (330-399 pin; see nix/checks.nix)
  users.groups.weather.gid = 345;
  users.users.weather = {
    isSystemUser = true;
    uid = 345;
    group = "weather";
  };

  virtualisation.oci-containers.containers.weather = {
    image = "ghcr.io/mwood77/ws4kp-international:latest";
    user = "${toString config.users.users.weather.uid}:${toString config.users.groups.weather.gid}";
    ports = [ "127.0.0.1:${toString port}:8080" ];
    environment.WS4KP_PORT = "8080";
  };
}
