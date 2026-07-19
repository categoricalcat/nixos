{
  pkgs,
  ...
}:

{
  systemd.services.goaccess = {
    description = "GoAccess real-time web log analyzer";
    after = [ "nginx.service" ];
    requires = [ "nginx.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.goaccess}/bin/goaccess /var/log/nginx/access.log -o /var/lib/goaccess/index.html --log-format=COMBINED --real-time-html --port=7890 --ws-url=wss://goaccess.fufu.land/ws";
      Restart = "always";
      RestartSec = "2";
      StateDirectory = "goaccess";
      User = "nginx";
      Group = "nginx";
      AmbientCapabilities = "";
      NoNewPrivileges = true;
    };
  };
}
