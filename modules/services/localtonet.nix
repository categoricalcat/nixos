{
  config,
  pkgs,
  ...
}:

{
  virtualisation.oci-containers.containers.localtonet = {
    image = "localtonet/localtonet";
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
}
