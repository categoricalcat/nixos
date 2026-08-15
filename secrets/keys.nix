# bad faith, are we? c:
let
  keysFolder = "/persist/keys";

  hosts = {
    yifuwuqi = {
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFg0dxFNC3NV4CrwxgpVbFiALycEquvuP3WzWgaY4/a3 root@nixos";
      ageRecipient = "age166h46fnvf528q282gyvz43k72dk2rsmpvc63nwrv45r9ceuj7qdqxq0day";
    };

    yitaishi = {
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlLwAuRQDI58Jmpzv7G5V8ltbEdtgMErZUTG65ZUFzx root@yitaishi";
      ageRecipient = "age16wh0k266hst8yffnwgxedksftqme6qjr3rxz453ezrl5yft47uwsfhye9m";
    };

    yirukou = {
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcmdHKr8j7x8uIx4qZ6qJTMS47YGsKHv1udKpR8eRbn root@nixos";
      ageRecipient = "age1netr6u2q9ecz56cslyhka9gqujgdul0zhgrppnnfw0v9wx46f3xqmte9an";
    };

    yixiaoqing = {
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9kVxqYIW4P8q9jm0DZ4YdZUynbgsUYoMR023HUhMZN root@fuyidong";
      ageRecipient = "age1u65y7my2zrctutytmhwjdjnrlqvk6x5vs42s4z333wldy9djeywsd63svn";
    };

  };

  users = {
    yi = rec {
      sshAuthorizedKeys = builtins.filter (x: x != null) (
        map (k: k.sshPublicKey) (builtins.attrValues meshKeys)
      );

      meshKeys = {
        yifuwuqi = {
          sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeXXVs6DAB79MLlw8ObQvY2j1Ld5ROaicFOurYgMBZX yi@yifuwuqi";
          ageRecipient = "age1l9zf799g73jd6zq5l7gxahqwhlsy8kn2gydqwnrmt7hrxtfj2acsvupjw2";
        };

        yitaishi = {
          sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINUpbp6NRYWITCqLUv3vLwbzH+R2wONlUHRSUvQgtQnr";
          ageRecipient = "age15gnjy25hw9dtu4t5qcjwtrnrs3wjawskqjmucpakhhzlap9p337q06hxep";
        };

        yirukou = {
          sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICU0876qeNJLIxk1PPOknm8gWxlbqbuSuy89FPofzh7W yi@yirukou";
          ageRecipient = "age1y94npwx0wk98lqhgsn4htm5uxu6q8757l5ggsqar534vwzxtl98sdcu4sg";
        };

        yixiaoqing = {
          sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnmvcucoKU8G0WLIV6NMsen1Es94bC/3yCRwOLEV2mP";
          ageRecipient = "age1avrhy95azlryttkfxuyu0cf2w00u97fwq04usghqg5sjx8qmg36sp7dm94";
        };
      };
    };

    # Read-only `ai` account (see docs/src/plans/ssh-mesh-hardening.md, Phase 3).
    # Generate the per-host keys on each mesh host with setup-sops.sh, then
    # replace each `null` below with the printed `sshPublicKey`. The ai gate
    # needs no secrets, so these are NOT sops age recipients.
    ai = rec {
      sshAuthorizedKeys = builtins.filter (x: x != null) (
        map (k: k.sshPublicKey) (builtins.attrValues meshKeys)
      );

      meshKeys = {
        yifuwuqi = {
          sshPublicKey = null;
        };

        yitaishi = {
          sshPublicKey = null;
        };

        yirukou = {
          sshPublicKey = null;
        };

        yixiaoqing = {
          sshPublicKey = null;
        };
      };
    };
  };

in
{
  paths = {
    inherit keysFolder;
    sopsConfigFile = "${keysFolder}/.sops.yaml";
    sshDir = "${keysFolder}/ssh";
    sshHostKey = "${keysFolder}/ssh/ssh_host_ed25519_key";
    sshHostPublicKey = "${keysFolder}/ssh/ssh_host_ed25519_key.pub";
    sopsDir = "${keysFolder}/sops";
    sopsDefaultFile = "${keysFolder}/sops/secrets.yaml";
    userSshKey = homeDir: "${homeDir}/.ssh/id_ed25519";
    userGitSshKey = homeDir: "${homeDir}/.ssh/id_git_ed25519";
    gitSigningKey = homeDir: "${homeDir}/.ssh/id_git_ed25519.pub";
  };

  inherit
    hosts
    users
    ;

  sopsAgeRecipients = builtins.filter (x: x != null) [
    hosts.yifuwuqi.ageRecipient
    hosts.yitaishi.ageRecipient
    hosts.yirukou.ageRecipient
    hosts.yixiaoqing.ageRecipient
    users.yi.meshKeys.yifuwuqi.ageRecipient
    users.yi.meshKeys.yitaishi.ageRecipient
    users.yi.meshKeys.yirukou.ageRecipient
    users.yi.meshKeys.yixiaoqing.ageRecipient
  ];
}
