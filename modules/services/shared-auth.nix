_:

{
  sops.secrets."services/htpasswd" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
  };
}
