# Clean-VM disaster-recovery drill: rehearses the bootstrap runbook's most
# dangerous assumption (docs/src/hardware/bootstrap-runbook.md) — that
# identity, secrets, ownership, and data come back together on a rebuilt
# machine — with synthetic keys only. Nothing real is encrypted or decrypted.
#
# `survivor` plays a keyed host walking the enrollment path (host SSH key
# migration -> age identity derivation -> sops encrypt to its own recipient,
# the secrets package's real commands from default.nix) and holds the backups
# (pg dump + filebrowser bolt-db tar). `rebuilt` plays the lost machine
# reinstalled from scratch: fresh identity, nothing decryptable until the
# survivor rekeys via `sops updatekeys` with the real creation-rules renderer
# (secrets/keys.nix sopsYamlFor), then restore, re-activate, and serve the
# restored state through the real local ingress.
#
# Deliberately out of scope: the `nixos-install` step itself (upstream-tested)
# and the AdGuard->Unbound resolver chain (modules/services/unbound.nix needs
# a host-local valkey; access is asserted at the ingress layer over the
# registry LAN address instead). The rebuilt node's spare disk stands in for
# the freshly installed root disk: bootstrap-disk partitions it with the
# exact runbook layout and its root partition is mounted at /persist, so every
# recovery step writes to the prepared volume.
{ sopsNix }:
let
  allAddresses = import ../modules/addresses.nix;
  yi = allAddresses.hosts.yifuwuqi;
  lan = yi.network.lan.ipv4.host;
  gateway = allAddresses.hosts.yirukou.network.lan.ipv4.host;
  inherit (yi.services) files ingress;
  inherit (files) domain;

  # The production creation-rules shape, rendered at test time with the two
  # in-test recipients. Placeholder lines are replaced in the test script;
  # the rekey path the drill exercises is the one sync-secrets.sh uses.
  rulesTemplate = (import ./keys.nix).sopsYamlFor [
    "@SURVIVOR_R@"
    "@REBUILT_R@"
  ];
in
{
  name = "dr-recovery";

  defaults =
    { config, pkgs, ... }:
    {
      _module.args.allAddresses = allAddresses;
      networking = {
        useNetworkd = true;
        useDHCP = false;
        # The drill targets recovery, not the edge policy.
        firewall.enable = false;
        # Registry lookups in the imported modules key on the host name.
        hostName = "yifuwuqi";
      };
      # nixos-install generates host keys during install; the openssh module
      # does the same here, so ensure-host-key migrates a real first-boot key.
      services.openssh.enable = true;

      users.users.yi = {
        isNormalUser = true;
        group = "yi";
      };
      users.groups.yi = { };

      environment = {
        # The preStart and the drill both drive the same binary.
        systemPackages = [
          config.services.filebrowser.package
          pkgs.sops
          # Brings its own tools; installing them here too would hide a
          # missing runtimeInput.
          (pkgs.callPackage ./default.nix { })
          pkgs.curl
          pkgs.jq
        ];
      };

      imports = [
        sopsNix.nixosModules.sops
        ./sops.nix
        ../modules/services/postgresql.nix
        ../modules/services/filebrowser.nix
      ];
    };

  nodes = {
    survivor = {
      virtualisation.memorySize = 1024;
      # The test framework puts the shared vlan-1 network on eth1 (its
      # default `virtualisation.vlans = [ 1 ]`; QEMU's built-in NIC keeps
      # eth0), so the registry LAN addresses go on eth1.
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = gateway;
          prefixLength = 24;
        }
      ];
    };

    rebuilt = {
      imports = [ ../modules/services/local-ingress.nix ];
      # The ingress is mTLS in production; the drill has no service CA or sops
      # keys, and what it verifies is recovery, so it keeps plain HTTP.
      yi.mtls.enable = false;
      virtualisation = {
        memorySize = 2048;
        # Sparse qcow2 sized for the runbook layout (1 GiB ESP + 32 GiB swap).
        emptyDiskImages = [ 36864 ];
      };
      networking.interfaces.eth1.ipv4.addresses = [
        {
          address = lan;
          prefixLength = 24;
        }
      ];
    };
  };

  testScript = ''
    import base64

    pw = "drill-synthetic-3f9a"  # synthetic; no real secret
    secret_path = "/run/secrets/passwords/filebrowser"
    host_key = "/persist/keys/ssh/ssh_host_ed25519_key"
    sops_yaml = "/persist/keys/sops/secrets.yaml"
    repo_yaml = "/root/repo/.sops.yaml"  # stands in for the repo's rendered .sops.yaml
    db = "/var/lib/filebrowser/database.db"
    ingress = "http://${lan}:${toString ingress.port}"
    files_host = "Host: ${domain}"
    # The enrollment steps, shared by both nodes' walks.
    enroll = (
        f"ensure-host-key {host_key} yifuwuqi"
        f" && derive-age-key {host_key} /root/.config/sops/age/keys.txt root:root"
    )

    start_all()

    with subtest("first boot is the honest empty-machine state"):
        for m in (survivor, rebuilt):
            m.wait_for_unit("postgresql.service")
            # No host identity at /persist: sops cannot decrypt anything yet.
            m.wait_until_succeeds("systemctl is-failed --quiet sops-install-secrets.service")
            m.wait_until_succeeds("systemctl is-failed --quiet filebrowser.service")
            m.fail(f"test -e {secret_path}")

    with subtest("survivor walks the enrollment path with the real scripts"):
        survivor.succeed(enroll)
        # nixos-install-style migration: the /persist key IS the first-boot key.
        etc_pub = survivor.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
        survivor_pub = survivor.succeed(f"cat {host_key}.pub").strip()
        assert etc_pub == survivor_pub, "host key was regenerated instead of migrated"
        sr = survivor.succeed(f"ssh-pub-to-age '{survivor_pub}'").strip()

        survivor.succeed(f"printf 'passwords:\\n  filebrowser: {pw}\\n' >/tmp/secrets-plain.yaml")
        # /persist/keys/sops exists with the declarative layout from
        # secrets/sops.nix (boot tmpfiles); only the repo copy and rules
        # render inside sync-secrets cannot run here.
        survivor.succeed(f"sops --encrypt --age {sr} /tmp/secrets-plain.yaml > {sops_yaml}")
        survivor.succeed(f"rm /tmp/secrets-plain.yaml; chmod 0600 {sops_yaml}")
        survivor.succeed("systemctl restart sops-install-secrets.service")
        owner = survivor.succeed(f"stat -c '%U:%G:%a' {secret_path}").strip()
        assert owner == "yi:yi:400", f"secret rendered as {owner}"
        # The first-boot preStart inited the bolt db but never created the
        # user (it failed on the missing secret), and bolt allows a single
        # opener: seed the backup-only state while the server is not holding
        # the database.
        survivor.succeed(
            f"filebrowser --database {db} users add restore-marker another-synthetic-pw --perm.admin=false"
        )
        survivor.succeed("systemctl restart filebrowser.service")
        survivor.wait_for_unit("filebrowser.service")

    with subtest("survivor produces the backup artifacts"):
        survivor.succeed(
            "runuser -u postgres -- psql -d forgejo -c 'create table if not exists drill_recovery (proof text)'"
        )
        survivor.succeed(
            "runuser -u postgres -- psql -d forgejo -c \"insert into drill_recovery values ('restored-payload')\""
        )
        survivor.succeed("runuser -u postgres -- pg_dump -d forgejo -f /tmp/forgejo.sql")
        survivor.succeed("tar -C /var/lib -czf /tmp/filebrowser.tgz filebrowser")

    with subtest("rebuilt reinstalls onto the prepared disk"):
        # Safety guards rehearsed: the running-root disk (/dev/vda) and the
        # prepared disk once its root partition is mounted must both refuse.
        rebuilt.fail("bootstrap-disk /dev/vda /mnt")
        rebuilt.succeed("bootstrap-disk /dev/vdb /persist")
        rebuilt.succeed("findmnt -t ext4 /persist")
        rebuilt.fail("bootstrap-disk /dev/vdb /tmp")
        rebuilt.succeed("lsblk -o PARTLABEL /dev/vdb | grep -q BOOT")
        # The declarative /persist layout (keys, sops, postgres roots; see
        # secrets/sops.nix and modules/services/postgresql.nix) re-creates on
        # the mounted disk in one sweep.
        rebuilt.succeed("systemd-tmpfiles --create")
        rebuilt.succeed(enroll)
        rebuilt_pub = rebuilt.succeed(f"cat {host_key}.pub").strip()
        rr = rebuilt.succeed(f"ssh-pub-to-age '{rebuilt_pub}'").strip()
        assert sr != rr, "rebuilt regenerated the survivor's identity"

    with subtest("survivor rekeys the secrets for the new identity"):
        rules = """${rulesTemplate}""".replace("@SURVIVOR_R@", sr).replace("@REBUILT_R@", rr)
        b64 = base64.b64encode(rules.encode()).decode()
        # The runbook's move, shape for shape: a "repo" copy of the secrets
        # file beside the rendered .sops.yaml, `sops updatekeys -y
        # secrets/secrets.yaml` from that directory (creation rules match
        # paths relative to the config), then the sync-secrets-style copy
        # back to /persist.
        survivor.succeed(
            "mkdir -p /root/repo/secrets"
            f" && cp {sops_yaml} /root/repo/secrets/secrets.yaml"
            f" && echo {b64} | base64 -d > {repo_yaml}"
        )
        survivor.succeed(
            "cd /root/repo"
            ' && SOPS_AGE_KEY="$(cat /root/.config/sops/age/keys.txt)" sops updatekeys -y secrets/secrets.yaml'
        )
        survivor.succeed(f"install -m 0600 -o root -g root /root/repo/secrets/secrets.yaml {sops_yaml}")
        survivor.succeed(f"cp {sops_yaml} /tmp/forgejo.sql /tmp/filebrowser.tgz /tmp/shared/")

    with subtest("rebuilt restores identity, secrets, and data"):
        rebuilt.succeed(f"install -m 0600 -o root -g root /tmp/shared/secrets.yaml {sops_yaml}")
        rebuilt.succeed("cp /tmp/shared/forgejo.sql /tmp/shared/filebrowser.tgz /tmp/")
        # Postgres moves onto the prepared disk: the tmpfiles sweep above
        # recreated the data roots there and a restart initdb's a fresh
        # cluster to restore into.
        rebuilt.succeed("systemctl restart postgresql.service")
        rebuilt.wait_for_unit("postgresql.service")
        # The ensure* setup unit (registry databases, roles) is a oneshot;
        # restart it so the fresh on-disk cluster gets them back.
        rebuilt.succeed("systemctl restart postgresql-setup.service")
        rebuilt.wait_for_unit("postgresql-setup.service")
        rebuilt.succeed("runuser -u postgres -- psql -d forgejo -f /tmp/forgejo.sql >/dev/null")
        row = rebuilt.succeed("runuser -u postgres -- psql -tAd forgejo -c 'select proof from drill_recovery'").strip()
        assert row == "restored-payload", f"pg restore returned {row!r}"

        rebuilt.succeed("tar -C /var/lib -xzf /tmp/filebrowser.tgz")
        owner = rebuilt.succeed(f"stat -c '%U:%G' {db}").strip()
        assert owner == "yi:yi", f"restored db owned by {owner}"

        # The restored bolt db carries the backup-only marker user; read it
        # while the server is not holding the database.
        users = rebuilt.succeed(f"filebrowser --database {db} users ls")
        assert "restore-marker" in users, "filebrowser backup did not restore"

        rebuilt.succeed("systemctl restart sops-install-secrets.service")
        decrypted = rebuilt.succeed(f"cat {secret_path}").strip()
        assert decrypted == pw, "rekeyed secrets do not decrypt under the rebuilt identity"
        rebuilt.succeed("systemctl restart filebrowser.service")
        rebuilt.wait_for_unit("filebrowser.service")

    with subtest("restored state is served through the real local ingress"):
        survivor.wait_until_succeeds("ping -c 1 -W 1 ${lan}")
        # The gateway allowlist in proxy-vhosts.nix admits only yirukou's LAN
        # address; the survivor holds it, so it can log into the restored
        # bolt db with the rekeyed secret and list the restored tree.
        # Type=simple units are active before their socket binds; the login
        # doubles as the serving gate (retries until the restored stack
        # answers through the ingress).
        survivor.wait_until_succeeds(
            "curl -sf -H 'Content-Type: application/json' "
            f'-d \'{{"username":"yi","password":"{pw}"}}\' -o /tmp/login.json '
            f"-H '{files_host}' {ingress}/api/login"
        )
        # v2 filebrowser returns either {"token": ...} or the raw JWT; both
        # shapes collapse to the token string.
        token = survivor.succeed(
            "jq -er .token /tmp/login.json 2>/dev/null || tr -d '\"' </tmp/login.json"
        ).strip()
        resources = survivor.succeed(
            f"curl -s -o /tmp/resources.out -w '%{{http_code}}' "
            f"-H 'X-Auth: {token}' -H '{files_host}' {ingress}/api/resources/"
        ).strip()
        assert resources == "200", (
            f"ingress listing answered {resources}: "
            + survivor.execute("head -c 300 /tmp/resources.out")[1]
        )
        # A non-gateway source is denied at the door, exactly as in production.
        denied = rebuilt.succeed(
            f"curl -s -o /dev/null -w '%{{http_code}}' -H '{files_host}' {ingress}/"
        ).strip()
        assert denied == "403", f"ingress answered {denied} to a non-gateway peer"

    with subtest("generate converges an unseeded CA host instead of failing"):
        # setup-sops chains `mtls-pki-generate` (nix run .#secrets). This node
        # is the registry's CA host, so an unseeded run mints the CA and its
        # own pair rather than exiting: the command is the seed, not a
        # follower. The peer half of the mesh needs SSH to yirukou, which the
        # drill does not have, so it warns and leaves the pair staged here.
        rebuilt.succeed("mtls-pki-generate")
        rebuilt.succeed("test -e /persist/keys/mtls/service-ca.crt")
        rebuilt.succeed("test -e /persist/keys/mtls/service-ca.key")
        rebuilt.succeed("test -e /persist/keys/mtls/yifuwuqi-server.crt")
        rebuilt.succeed("test -e /persist/keys/mtls/yifuwuqi-client.crt")
        # Own pair is group-readable for the mtls consumers, the CA key never.
        rebuilt.succeed("test \"$(stat -c %a /persist/keys/mtls/service-ca.key)\" = 600")
        rebuilt.succeed("test \"$(stat -c %a /persist/keys/mtls/yifuwuqi-server.key)\" = 640")
        # Idempotent: a second run signs nothing new.
        before = rebuilt.succeed("sha256sum /persist/keys/mtls/*-server.crt")
        rebuilt.succeed("mtls-pki-generate")
        assert rebuilt.succeed("sha256sum /persist/keys/mtls/*-server.crt") == before

    with subtest("rotate re-signs this host's pair against the existing CA"):
        # The CA key is here now, so rotate has to work: it replaces the pair
        # and leaves the CA alone.
        ca = rebuilt.succeed("sha256sum /persist/keys/mtls/service-ca.crt")
        old = rebuilt.succeed("sha256sum /persist/keys/mtls/yifuwuqi-server.crt")
        rebuilt.succeed("mtls-pki-rotate")
        assert rebuilt.succeed("sha256sum /persist/keys/mtls/service-ca.crt") == ca
        new = rebuilt.succeed("sha256sum /persist/keys/mtls/yifuwuqi-server.crt")
        assert new != old, "rotate did not re-sign this host's leaf"

    # The peer half of the mesh opens SSH, which the drill does not have, so
    # the push/skip/unreachable behaviour is covered at implementation time
    # against an ssh stub.
  '';
}
