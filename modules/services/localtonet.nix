{
  config,
  ...
}:

{
  users.users.localtonet = {
    isSystemUser = true;
    group = "localtonet";
    description = "Localtonet service user";
    home = "/var/lib/localtonet";
    createHome = true;
  };
  users.groups.localtonet = { };

  virtualisation.oci-containers.containers.localtonet = {
    image = "localtonet/localtonet";
    user = "${toString config.users.users.localtonet.uid}:${toString config.users.groups.localtonet.gid}";
    volumes = [
      "${config.sops.secrets."tokens/localtonet-authtoken".path}:/token"
    ];
    entrypoint = "sh";
    cmd = [
      "-c"
      "dotnet localtonet.dll --authtoken $(cat /token)"
    ];
    autoStart = true;
  };

  sops.secrets."tokens/localtonet-authtoken" = {
    mode = "0640"; # Read by the container
  };
}
