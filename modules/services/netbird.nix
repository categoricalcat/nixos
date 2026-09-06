{ pkgs, ... }:
{
  services.netbird = {
    enable = true;
    package = pkgs.netbird;
    clients.default.environment = {
      NB_LAZY_CONN = "false";
    };
  };

  # The NixOS netbird module adds a wrapper to systemPackages that sets NB_CONFIG,
  # which causes the deprecation warning when running `netbird up`.
  # Providing the unwrapped package with hiPrio overrides the wrapper in $PATH,
  # keeping the CLI clean while the systemd service still uses the wrapper.
  environment.systemPackages = [ (pkgs.lib.hiPrio pkgs.netbird) ];

  networking.firewall.trustedInterfaces = [ "wt0" ];
}
