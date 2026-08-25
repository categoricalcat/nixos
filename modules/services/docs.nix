{
  pkgs,
  addresses,
  ...
}:

let
  fleetDocs = pkgs.stdenv.mkDerivation {
    name = "fleet-docs";
    src = ../../docs;
    nativeBuildInputs = [ pkgs.mdbook ];
    buildPhase = ''
      echo -e "\n## Plans\n" >> src/SUMMARY.md
      for plan in src/plans/*.md; do
        if [ -f "$plan" ]; then
          plan_name=$(basename "$plan" .md | tr '-' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
          echo "- [$plan_name](plans/$(basename "$plan"))" >> src/SUMMARY.md
        fi
      done
      mdbook build
    '';
    installPhase = "cp -r book $out";
  };
in
{
  systemd.services.docs = {
    description = "Fleet Documentation HTTP Server (darkhttpd)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${fleetDocs} --port ${toString addresses.services.docs.port} --addr 0.0.0.0 --no-listing --no-server-id --hide-dotfiles";
      DynamicUser = true;
      Restart = "always";

      # Core security boundary
      CapabilityBoundingSet = "";
      ProtectHome = true;
      PrivateDevices = true;
      ProtectProc = "invisible";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];
    };
  };
}
