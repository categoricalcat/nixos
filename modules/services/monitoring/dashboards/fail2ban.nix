_:
let
  dashLib = import ./lib.nix;
in
dashLib.mkDashboard {
  uid = "fail2ban";
  title = "Fail2Ban";
  panels = [
    (dashLib.mkStat {
      title = "Currently Banned IPs";
      expr = "sum(f2b_jail_banned_current)";
      gridPos = dashLib.mkGridPos 0 0 12 4;
    })
    (dashLib.mkTimeseries {
      title = "Banned IPs per Jail";
      expr = "f2b_jail_banned_current";
      gridPos = dashLib.mkGridPos 0 4 24 10;
      legendFormat = "{{jail}}";
    })
  ];
}
