# Derived host-address alias suffixes. Consumed via modules/addresses.nix.
# `lan` and `local` both cover the LAN v6/v4 host paths; `ts` is tailnet v4.
builtins.concatMap
  (
    suffix:
    map
      (family: {
        inherit suffix;
        path = [
          "network"
          "lan"
          family
          "host"
        ];
      })
      [
        "ipv6"
        "ipv4"
      ]
  )
  [
    "lan"
    "local"
  ]
++ [
  {
    suffix = "ts";
    path = [
      "network"
      "tailscale"
      "ipv4"
      "host"
    ];
  }
]
