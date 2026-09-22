# bad faith, are we? c:
let
  keysFolder = "/persist/keys";

  # One block per machine: identities it owns and identities it accepts.
  machines = rec {
    yifuwuqi = {
      host = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFg0dxFNC3NV4CrwxgpVbFiALycEquvuP3WzWgaY4/a3 root@nixos";
        age = "age166h46fnvf528q282gyvz43k72dk2rsmpvc63nwrv45r9ceuj7qdqxq0day";
      };
      yi = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeXXVs6DAB79MLlw8ObQvY2j1Ld5ROaicFOurYgMBZX yi@yifuwuqi";
        age = "age1l9zf799g73jd6zq5l7gxahqwhlsy8kn2gydqwnrmt7hrxtfj2acsvupjw2";
      };
      ai.ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIfeDtTmqxtZAJem+P21xb+YSFxUQW1UP2NCVFy10YAJ ai@yifuwuqi";
      allow = {
        root = rootAdmins;
        yi = [
          yitaishi.yi.ssh
          yixiaoqing.yi.ssh
        ];
        ai = aiAgent;
      };
    };

    yitaishi = {
      host = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlLwAuRQDI58Jmpzv7G5V8ltbEdtgMErZUTG65ZUFzx root@yitaishi";
        age = "age16wh0k266hst8yffnwgxedksftqme6qjr3rxz453ezrl5yft47uwsfhye9m";
      };
      yi = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINUpbp6NRYWITCqLUv3vLwbzH+R2wONlUHRSUvQgtQnr";
        age = "age15gnjy25hw9dtu4t5qcjwtrnrs3wjawskqjmucpakhhzlap9p337q06hxep";
      };
      ai.ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAeFhfoGC6M5MfcnqSPTU0yRnxTHT6MxYUiR2HqjXYRt ai@yitaishi";
      allow = {
        root = rootAdmins;
        yi = [ ];
        ai = aiAgent;
      };
    };

    yirukou = {
      host = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcmdHKr8j7x8uIx4qZ6qJTMS47YGsKHv1udKpR8eRbn root@nixos";
        age = "age1netr6u2q9ecz56cslyhka9gqujgdul0zhgrppnnfw0v9wx46f3xqmte9an";
      };
      yi = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICU0876qeNJLIxk1PPOknm8gWxlbqbuSuy89FPofzh7W yi@yirukou";
        age = "age1y94npwx0wk98lqhgsn4htm5uxu6q8757l5ggsqar534vwzxtl98sdcu4sg";
      };
      ai.ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICKpimnH0veob7IVu4y1EWEmicQFLrMSXf185BOjMzDi ai@yirukou";
      allow = {
        root = rootAdmins;
        yi = [ yifuwuqi.yi.ssh ];
        ai = aiAgent;
      };
    };

    yixiaoqing = {
      host = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9kVxqYIW4P8q9jm0DZ4YdZUynbgsUYoMR023HUhMZN root@fuyidong";
        age = "age1u65y7my2zrctutytmhwjdjnrlqvk6x5vs42s4z333wldy9djeywsd63svn";
      };
      yi = {
        ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnmvcucoKU8G0WLIV6NMsen1Es94bC/3yCRwOLEV2mP";
        age = "age1avrhy95azlryttkfxuyu0cf2w00u97fwq04usghqg5sjx8qmg36sp7dm94";
      };
      ai.ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMvsQ0jz1OKb1QOm7VfniDauBrCa1WeZNwnXzhIf1dud ai@yixiaoqing";
      allow = {
        root = rootAdmins;
        yi = [ ];
        ai = aiAgent;
      };
    };

    yichuang.allow = {
      root = [ ];
      yi = [ ];
      ai = [ ];
    };
  };

  ci = {
    deployPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINg1PN5erwfilOhC9MEMSgEf0Mvvnh9+cv/l2oRorDuX nix-builder@yifuwuqi";
  };

  rootAdmins = [
    ci.deployPublicKey
    machines.yifuwuqi.host.ssh
  ];
  aiAgent = [ machines.yifuwuqi.ai.ssh ];

  keyed = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = machines.${name};
      })
      [
        "yifuwuqi"
        "yirukou"
        "yitaishi"
        "yixiaoqing"
      ]
  );

  hosts = builtins.mapAttrs (_: machine: {
    sshPublicKey = machine.host.ssh;
    ageRecipient = machine.host.age;
  }) keyed;

  users = {
    yi.meshKeys = builtins.mapAttrs (_: machine: {
      sshPublicKey = machine.yi.ssh;
      ageRecipient = machine.yi.age;
    }) keyed;

    # Read-only `ai` account (see docs/src/services/ai-ssh.md).
    ai.meshKeys = builtins.mapAttrs (_: machine: { sshPublicKey = machine.ai.ssh; }) keyed;
  };

  access = builtins.listToAttrs (
    map
      (account: {
        name = account;
        value = builtins.mapAttrs (_: machine: machine.allow.${account}) machines;
      })
      [
        "root"
        "yi"
        "ai"
      ]
  );

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
    ci
    access
    ;

  # Root decrypts with the host key, `yi` with their per-machine mesh key.
  sopsAgeRecipients = builtins.concatMap (machine: [
    machine.host.age
    machine.yi.age
  ]) (builtins.attrValues keyed);
}
