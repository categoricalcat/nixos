{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  dashLib = import ./lib.nix { inherit lib; };
in
dashLib.mkDashboard {
  uid = "fail2ban";
  title = "Fail2Ban";
  panels = [
    (dashLib.mkStat {
      title = "Currently Banned IPs";
      expr = "sum(fail2ban_banned_ips)";
      gridPos = dashLib.mkGridPos 0 0 12 4;
    })
    (dashLib.mkTimeseries {
      title = "Banned IPs per Jail";
      expr = "fail2ban_banned_ips";
      gridPos = dashLib.mkGridPos 0 4 24 10;
      legendFormat = "{{jail}}";
    })
  ];
}
