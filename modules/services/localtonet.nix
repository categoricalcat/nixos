{
  config,
  ...
}:

{
  # Pinned so the container `user` renders at eval time (unpinned accounts
  # render "null:null" and the container silently runs as root).
  users.groups.localtonet.gid = 346;
  users.users.localtonet = {
    isSystemUser = true;
    uid = 346;
    group = "localtonet";
    description = "Localtonet service user";
    home = "/var/lib/localtonet";
    createHome = true;
  };

  sops.templates."localtonet.env".content = ''
    LOCALTONET_AUTH_TOKEN=${config.sops.placeholder."tokens/localtonet-authtoken"}
  '';

  virtualisation.oci-containers.containers.localtonet = {
    image = "localtonet/localtonet";
    user = "${toString config.users.users.localtonet.uid}:${toString config.users.groups.localtonet.gid}";
    environmentFiles = [
      config.sops.templates."localtonet.env".path
    ];
    entrypoint = "sh";
    cmd = [
      "-c"
      "dotnet localtonet.dll --authtoken $LOCALTONET_AUTH_TOKEN"
    ];
    autoStart = true;
  };

  sops.secrets."tokens/localtonet-authtoken" = { };
}
