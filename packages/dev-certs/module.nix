{
  config,
  lib,
  pkgs,
  ...
}:

let
  dir = "/persist/keys/dev";
  ca = "${dir}/ca.pem";
in
{
  users.groups.devcert.members = [ "yi" ] ++ lib.optional config.host.workd "workd";

  # The CA's own name constraints bound every verifier below (OpenSSL, Go,
  # Node, Chrome) and its key is discarded after signing. The files stay out
  # of the public repo and Nix store; minted by dev-certs-setup (README.md in
  # this directory). Missing files are skipped.
  systemd.tmpfiles.settings.dev-certs."${dir}/key.pem".z = {
    mode = "0640";
    user = "root";
    group = "devcert";
  };

  environment = {
    etc = {
      # `openssl x509 -subject_hash` of CN=aset dev CA. OpenSSL's compiled-in
      # CA directory lives in the store, hence SSL_CERT_DIR.
      "ssl/certs/4ce7bcbb.0".source = ca;
      "opt/chrome/policies/managed/dev-ca.json" = lib.mkIf config.programs.chromium.enable {
        source = "${dir}/chrome.json";
      };
    };
    sessionVariables = {
      SSL_CERT_DIR = "/etc/ssl/certs";
      NODE_EXTRA_CA_CERTS = ca;
    };
    systemPackages = [ (pkgs.callPackage ./default.nix { }) ];
  };
}
