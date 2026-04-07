{ config, lib, ... }:

{
  warnings = lib.optional (config.sops.defaultSopsFile == "") ''
    zerotier: sops.defaultSopsFile is not set.
    The secret "zerotier/network_id" will not be available.
  '';

  sops.secrets."zerotier/network_id" = { };

  services.zerotierone = {
    enable = true;
    joinNetworks = [ config.sops.placeholder."zerotier/network_id" ];
  };

  # Do not start automatically on boot. Can be started manually with `systemctl start zerotierone`
  systemd.services.zerotierone.wantedBy = lib.mkForce [ ];

  sops.templates."zerotier.env".content = config.sops.placeholder."zerotier/network_id";

  networking.firewall.trustedInterfaces = [ "zt+" ];

  # SMB ports on ZeroTier — zt+ wildcard doesn't translate to nftables zt*,
  # so trustedInterfaces alone won't open these ports on ZeroTier interfaces.
  networking.firewall.extraInputRules = ''
    iifname "zt*" tcp dport { 139, 445 } accept
    iifname "zt*" udp dport { 137, 138 } accept
  '';

  # warning if sops env is not set

}
