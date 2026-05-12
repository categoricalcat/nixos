_:

{
  sops.secrets."services/htpasswd" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
  };

  # Ensure the nginx user and group exist so sops-install-secrets doesn't fail
  users.groups.nginx = { };
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
  };
}
