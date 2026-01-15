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
