{
  pkgs,
  config,
  ...
}:

{
  sops.secrets."webdav/htpasswd" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
  };

  services.nginx = {
    additionalModules = [ pkgs.nginxModules.dav ];

    virtualHosts."webdav.fufu.land" = {
      useACMEHost = "fufu.land";
      forceSSL = true;
      http2 = false;

      extraConfig = ''
        error_log /var/log/nginx/webdav-error.log info;
      '';

      locations."/" = {
        root = "/srv/webdav";
        extraConfig = ''
          dav_methods PUT DELETE MKCOL COPY MOVE;
          dav_ext_methods PROPFIND OPTIONS LOCK UNLOCK;
          dav_access user:rw group:rw;
          create_full_put_path on;

          client_max_body_size 0;

          auth_basic "WebDAV";
          auth_basic_user_file ${config.sops.secrets."webdav/htpasswd".path};

          autoindex on;
        '';
      };
    };
  };

  systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/srv/webdav" ];

  systemd.tmpfiles.rules = [
    "d /srv/webdav 0775 nginx nginx -"
  ];
}
