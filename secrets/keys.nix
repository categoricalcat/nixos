let
  keysFolder = "/persist/keys";

  hosts = {
    yifuwuqi = {
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFg0dxFNC3NV4CrwxgpVbFiALycEquvuP3WzWgaY4/a3";
      ageRecipient = "age166h46fnvf528q282gyvz43k72dk2rsmpvc63nwrv45r9ceuj7qdqxq0day";
    };

    yitaishi = {
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlLwAuRQDI58Jmpzv7G5V8ltbEdtgMErZUTG65ZUFzx";
      ageRecipient = "age16wh0k266hst8yffnwgxedksftqme6qjr3rxz453ezrl5yft47uwsfhye9m";
    };

    yirukou = {
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcmdHKr8j7x8uIx4qZ6qJTMS47YGsKHv1udKpR8eRbn";
      ageRecipient = "age1netr6u2q9ecz56cslyhka9gqujgdul0zhgrppnnfw0v9wx46f3xqmte9an";
    };

    # Fill this in after the host is reachable or its public host key is copied
    # out-of-band. Do not guess this value.
    yixiaoqing = {
      sshPublicKey = null;
      ageRecipient = null;
    };

    yichuang = {
      sshPublicKey = null;
      ageRecipient = null;
    };
  };

  users = {
    yi = {
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMFdaKOm9/19z4mhVMClEPewSLIzDDpHDNKLrernUrEK fufud@fuyidong"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFkKk0FdFj+g/+uJgJiF5ukH8Oazzx0p2Ae0jb8aUVB9 fufud@fuchuang"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMmSvhc3u+aAXkWFSOOT+OPq0xbkRzmXAAHfuMjx+uk yi@nixos"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnmvcucoKU8G0WLIV6NMsen1Es94bC/3yCRwOLEV2mP"
      ];

      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeXXVs6DAB79MLlw8ObQvY2j1Ld5ROaicFOurYgMBZX yi@yifuwuqi";
      ageRecipient = "age1l9zf799g73jd6zq5l7gxahqwhlsy8kn2gydqwnrmt7hrxtfj2acsvupjw2";
    };
  };

  legacy = {
    # Existing recipient from the current .sops.yaml/key.txt migration path.
    # Keep this until every host has switched and decrypted via the persisted
    # SSH host key identity.
    sopsAgeRecipient = "age1gftvv43376wv8djfuntn596pk3mv75dhv5fe99la9q29p4dqldnqqwf45h";
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
    sopsFallbackKeyFile = "${keysFolder}/sops/key.txt";
    # User SSH private key (for sops age identity derivation, etc.)
    userSshKey = homeDir: "${homeDir}/.ssh/id_ed25519";
  };

  inherit
    hosts
    users
    legacy
    ;

  sopsAgeRecipients = [
    hosts.yifuwuqi.ageRecipient
    hosts.yitaishi.ageRecipient
    hosts.yirukou.ageRecipient
    users.yi.ageRecipient
    legacy.sopsAgeRecipient
  ];
}
