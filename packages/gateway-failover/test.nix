# Boots the real uplink units of both failover hosts against two fake
# upstreams and replays the ways the default route went missing or stayed on
# a dead uplink in production. Each has to converge without anyone touching a
# cable.
let
  allAddresses = import ../../modules/addresses.nix;
  inherit (allAddresses.hosts) yifuwuqi yirukou;

  prom = "${allAddresses.monitoring.nodeTextfileDir}/gateway_failover.prom";

  # An ordinary off-net address. Unlike the probe targets it is not pinned to
  # the primary, so it follows whichever default route is in force.
  destination = "203.0.113.1";

  # What both upstreams share: leases on eth1 and every off-net address on
  # wan0. Taking wan0 down keeps link and leases but blackholes whatever lies
  # behind them, which is what a dead ISP looks like from the edge.
  upstream = {
    systemd.network = {
      netdevs."10-wan0".netdevConfig = {
        Kind = "dummy";
        Name = "wan0";
      };
      networks = {
        "10-wan0" = {
          matchConfig.Name = "wan0";
          address = map (host: "${host}/32") ([ destination ] ++ yirukou.gatewayFailover.pingTargets);
        };
        "10-eth1" = {
          matchConfig.Name = "eth1";
          networkConfig.DHCPServer = true;
          # Keeps leases clear of yifuwuqi's static address on isp1's subnet.
          dhcpServerConfig = {
            PoolOffset = 100;
            PoolSize = 50;
          };
        };
      };
    };
  };
in
{
  name = "gateway-failover";

  defaults.networking = {
    useNetworkd = true;
    useDHCP = false;
    firewall.enable = false;
  };

  # Each edge runs a host's own uplink units on virtual NICs of the same
  # names: the primary on vlan 1, the fallback on vlan 2.
  nodes = {
    isp1 = {
      imports = [ upstream ];
      virtualisation.interfaces.eth1.vlan = 1;
      # yifuwuqi's static primary expects its gateway at this address;
      # yirukou's primary takes whatever lease it is offered.
      systemd.network.networks."10-eth1".address = [
        "${yifuwuqi.network.lan.ipv4.gateway}/${toString yifuwuqi.network.lan.ipv4.prefixLength}"
      ];
    };

    isp2 = {
      imports = [ upstream ];
      virtualisation.interfaces.eth1.vlan = 2;
      systemd.network.networks."10-eth1".address = [
        "${yifuwuqi.network.secondary.ipv4.gateway}/${toString yifuwuqi.network.secondary.ipv4.prefixLength}"
      ];
    };

    dhcpEdge = {
      imports = [
        ./default.nix
        ../../hosts/yirukou/networking/wans.nix
      ];
      _module.args = {
        inherit allAddresses;
        addresses = yirukou;
      };
      virtualisation.interfaces = {
        ${yirukou.network.wan.primary.interface}.vlan = 1;
        ${yirukou.network.wan.fallback.interface}.vlan = 2;
      };
    };

    staticEdge = {
      imports = [
        ./default.nix
        ../../hosts/yifuwuqi/networking/interfaces/eno1.nix
        ../../hosts/yifuwuqi/networking/interfaces/enp4s0.nix
      ];
      _module.args = {
        inherit allAddresses;
        addresses = yifuwuqi;
      };
      virtualisation.interfaces = {
        ${yifuwuqi.network.lan.interface}.vlan = 1;
        ${yifuwuqi.network.secondary.interface}.vlan = 2;
      };
    };
  };

  testScript = ''
    import datetime as dt

    soon = dt.timedelta(seconds=60)
    # The monitor ticks every 2 s; this leaves a slow builder some slack.
    few_ticks = dt.timedelta(seconds=10)

    edges = [
        (dhcpEdge, "${yirukou.network.wan.primary.interface}", "${yirukou.network.wan.fallback.interface}"),
        (staticEdge, "${yifuwuqi.network.lan.interface}", "${yifuwuqi.network.secondary.interface}"),
    ]


    def default_via(iface: str) -> str:
        return f"ip -4 route show default dev {iface} | grep -q ."


    def leaves_through(edge: QemuMachine, iface: str) -> None:
        edge.wait_until_succeeds(
            f"ip -4 route get ${destination} | grep -q 'dev {iface} ' && ping -c 1 -W 1 ${destination}",
            timeout=soon,
        )


    def publishes(edge: QemuMachine, primary: str, active: int) -> None:
        edge.wait_until_succeeds(
            f"""grep -qxF 'gateway_failover_primary_active{{interface="{primary}"}} {active}' ${prom}""",
            timeout=soon,
        )


    def set_carrier(edge: QemuMachine, iface: str, state: str) -> None:
        mac = edge.succeed(f"cat /sys/class/net/{iface}/address").strip()
        nic = next(
            line.split(":")[0].strip()
            for line in edge.send_monitor_command("info network").splitlines()
            if mac in line
        )
        edge.send_monitor_command(f"set_link {nic} {state}")


    start_all()
    for edge, _, _ in edges:
        edge.wait_for_unit("wan-monitor.service")

    with subtest("healthy boot leaves through the primary with the fallback standing by"):
        for edge, primary, fallback in edges:
            leaves_through(edge, primary)
            edge.wait_until_succeeds(f"ip -4 route show default dev {fallback} | grep -q 'proto dhcp'", timeout=soon)
            publishes(edge, primary, 1)

    with subtest("soft failure moves egress to the fallback"):
        withdrawn = {
            edge.name: edge.succeed(f"ip -4 route show default dev {primary}").strip()
            for edge, primary, _ in edges
        }
        isp1.succeed("ip link set wan0 down")
        for edge, primary, fallback in edges:
            leaves_through(edge, fallback)
            edge.fail(default_via(primary))
            publishes(edge, primary, 0)

    with subtest("a primary default put back during the failure is gone within a tick, with no transition"):
        for edge, primary, _ in edges:
            published = edge.succeed("cat ${prom}")
            edge.succeed(f"ip route add {withdrawn[edge.name]} dev {primary}")
            edge.wait_until_fails(default_via(primary), timeout=few_ticks)
            assert edge.succeed("cat ${prom}") == published

    with subtest("fallback carrier flap during the failure restores the fallback default"):
        for edge, _, fallback in edges:
            set_carrier(edge, fallback, "off")
            edge.wait_until_fails("ip -4 route show default | grep -q .", timeout=soon)
            set_carrier(edge, fallback, "on")
            leaves_through(edge, fallback)

    with subtest("reboot with the primary dead comes up on the fallback and stays there"):
        for edge, _, _ in edges:
            edge.shutdown()
        for edge, _, _ in edges:
            edge.start()
        for edge, _, fallback in edges:
            edge.wait_for_unit("wan-monitor.service")
            leaves_through(edge, fallback)
        for edge, primary, _ in edges:
            # Outlast the rise debounce: a primary that was going to return has.
            edge.sleep(duration=dt.timedelta(seconds=6))
            edge.fail(default_via(primary))

    with subtest("heal returns egress to the primary"):
        isp1.succeed("ip link set wan0 up")
        for edge, primary, _ in edges:
            leaves_through(edge, primary)
            publishes(edge, primary, 1)

    with subtest("a deleted primary default is back within a tick, with no transition"):
        for edge, primary, _ in edges:
            published = edge.succeed("cat ${prom}")
            edge.succeed(f"ip route del default dev {primary}")
            edge.wait_until_succeeds(default_via(primary), timeout=few_ticks)
            assert edge.succeed("cat ${prom}") == published

    with subtest("primary carrier flap fails over and back"):
        for edge, primary, fallback in edges:
            set_carrier(edge, primary, "off")
            leaves_through(edge, fallback)
            publishes(edge, primary, 0)
            set_carrier(edge, primary, "on")
            leaves_through(edge, primary)
            publishes(edge, primary, 1)

    with subtest("restart adopts the routes without touching them"):
        for edge, primary, _ in edges:
            published = edge.succeed("cat ${prom}")
            events = edge.succeed(
                "ip -4 monitor route >/tmp/route-events 2>&1 & monitor=$!;"
                " systemctl restart wan-monitor.service; sleep 6; kill $monitor;"
                " cat /tmp/route-events"
            )
            assert events == "", f"routes changed across the restart:\n{events}"
            assert edge.succeed("cat ${prom}") == published
            edge.succeed(default_via(primary))
  '';
}
