{
  pkgs,
  inputs,
  ...
}:

let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  systemd.services.goaccess = {
    description = "GoAccess real-time web log analyzer";
    after = [ "nginx.service" ];
    requires = [ "nginx.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${unstable.goaccess}/bin/goaccess /var/log/nginx/access.log --log-format=COMBINED --real-time-html --port=7890";
      Restart = "always";
      RestartSec = "2";
      AmbientCapabilities = "";
      NoNewPrivileges = true;
    };
  };
}
