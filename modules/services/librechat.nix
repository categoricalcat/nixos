# LibreChat web UI on chat.fufu.land.
#
# - Uses the upstream `services.librechat` module from nixpkgs-unstable
#   (the module hasn't been backported to nixos-25.11 yet, but the
#   `librechat` package itself is in our pinned nixpkgs-small, so the
#   default `pkgs.librechat` resolves fine).
# - Local MongoDB enabled via `services.librechat.enableLocalDB = true`,
#   which the upstream module wires to `services.mongodb`.
# - DeepSeek + Ollama exposed as custom OpenAI-compatible endpoints.
# - Native SearXNG web search hits the local SearXNG on 127.0.0.1:8888,
#   bypassing the public htpasswd-protected vhost (SearXNG itself binds
#   to loopback only).
# - LibreChat has no anonymous mode; first boot allows registration so an
#   account can be created, then ALLOW_REGISTRATION should be flipped to
#   false on a follow-up rebuild.
# - The four crypto keys (CREDS_KEY, CREDS_IV, JWT_SECRET, JWT_REFRESH_SECRET)
#   are generated on first boot into a stateful local file outside the nix
#   store (rotate by deleting and restarting), mirroring searx-secret-init.
#   The deepseek API key keeps flowing from sops via systemd LoadCredential.

{
  config,
  pkgs,
  inputs,
  ...
}:

let
  secretDir = "/var/lib/librechat-secret";
  secretEnv = "${secretDir}/env";
in
{
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/librechat.nix"
  ];

  systemd.tmpfiles.rules = [
    "d ${secretDir} 0750 librechat librechat -"
  ];

  systemd.services.librechat-secret-init = {
    description = "Generate LibreChat CREDS / JWT secrets on first boot";
    wantedBy = [ "librechat.service" ];
    before = [ "librechat.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -s ${secretEnv} ]; then
        umask 077
        {
          printf 'CREDS_KEY=%s\n'           "$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          printf 'CREDS_IV=%s\n'            "$(${pkgs.openssl}/bin/openssl rand -hex 16)"
          printf 'JWT_SECRET=%s\n'          "$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          printf 'JWT_REFRESH_SECRET=%s\n'  "$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        } > ${secretEnv}
        chown librechat:librechat ${secretEnv}
        chmod 0440 ${secretEnv}
      fi
    '';
  };

  services.librechat = {
    enable = true;
    enableLocalDB = true;

    env = {
      HOST = "127.0.0.1";
      PORT = 3080;
      DOMAIN_CLIENT = "https://chat.fufu.land";
      DOMAIN_SERVER = "https://chat.fufu.land";
      ALLOW_REGISTRATION = true;
      ALLOW_EMAIL_LOGIN = true;
      ALLOW_SOCIAL_LOGIN = false;
      ENDPOINTS = "custom";
    };

    credentialsFile = secretEnv;

    credentials = {
      DEEPSEEK_API_KEY = config.sops.secrets."tokens/deepseek".path;
    };

    settings = {
      version = "1.2.1";
      cache = true;

      endpoints.custom = [
        {
          name = "DeepSeek";
          apiKey = "\${DEEPSEEK_API_KEY}";
          baseURL = "https://api.deepseek.com/v1";
          models = {
            default = [
              "deepseek-chat"
              "deepseek-reasoner"
            ];
            fetch = false;
          };
          titleConvo = true;
          titleModel = "deepseek-chat";
          modelDisplayLabel = "DeepSeek";
        }
        {
          name = "Ollama";
          apiKey = "ollama";
          baseURL = "http://127.0.0.1:11434/v1/";
          models = {
            default = [ "qwen2.5:7b" ];
            fetch = true;
          };
          titleConvo = true;
          titleModel = "current_model";
          modelDisplayLabel = "Ollama";
        }
      ];

      webSearch = {
        searchProvider = "searxng";
        searxngInstanceUrl = "http://127.0.0.1:8888";
      };
    };
  };

  systemd.services.librechat = {
    after = [
      "librechat-secret-init.service"
      "mongodb.service"
      "searx.service"
    ];
    requires = [ "librechat-secret-init.service" ];
    wants = [
      "mongodb.service"
      "searx.service"
    ];
  };
}
