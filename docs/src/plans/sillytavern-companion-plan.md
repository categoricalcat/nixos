# Plan: Local AI companion (SillyTavern + Wiro image API) on yifuwuqi

Status: **implemented** (2026-08-03) — implemented and deployed. Decisions locked in
during planning: no TTS for now, non-abliterated `qwen3.6-35b-a3b` gets
disabled to free RAM, access via `companion.fufu.land` restricted to LAN + VPN.

## Objective

A Candy-AI-style local companion: SillyTavern frontend (zero-VRAM, Node app)
talking to the existing local `qwen3.6-35b-abliterated` llama-server unit on
yifuwuqi, with NSFW image generation via the paid **Wiro AI** API (Seedream
5.0 Lite uncensored, pay-per-image). No local image gen (680M iGPU + 19.3 GiB
RAM cannot run the 35B model and SD concurrently).

## Architecture

```
browser ──companion.fufu.land──▶ nginx (LAN+VPN CIDR allowlist)
                                    └─▶ 127.0.0.1:8000 SillyTavern (whitelist mode)
                                            ├─▶ Chat Completion (OpenAI) ──▶ llama-server :11437
                                            │        (qwen3.6-35b-abliterated, local, Vulkan)
                                            └─▶ Image Gen (Custom provider) ──▶ https://api.wiro.ai/v1/generate
                                                     (Bearer key, seedream-5-lite-uncensored)
```

- Chat is 100% local; only image requests leave the host.
- SillyTavern data (characters, settings, Wiro key) persists in
  `/var/lib/SillyTavern` (StateDirectory) across rebuilds.
- Security: SillyTavern binds 127.0.0.1 with whitelist mode (direct access
  blocked); nginx `restrictedProxyConfig` gates everything (LAN + VPN only,
  same pattern as forgejo/jellyfin). Keep nixpkgs updated — ST had RCE CVEs.

## Changes to apply

### 1. `modules/addresses.nix` — register the service

In `yifuwuqi.services`:

```nix
sillytavern = {
  domain = "companion.fufu.land";
  port = 8000;
};
```

### 2. NEW `modules/services/ai/sillytavern.nix` — service wrapper

Wraps the nixpkgs module (`services.sillytavern`, web-apps/sillytavern.nix)
so it can wire in host-specific bits (port from addresses registry, model
dependency, no extra secrets — the Wiro key lives in ST's own settings):

- `services.sillytavern = { enable, port = 8000, listenAddressIPv4 = "127.0.0.1", whitelist = true }`
- extra `systemd.services.sillytavern` ordering:
  `after`/`wants` → `llama-cpp-qwen3-6-35b-abliterated` so the companion
  model auto-starts whenever ST starts (llama-cpp units intentionally have
  no `wantedBy`).
- Data: nixpkgs module already sets `StateDirectory = "SillyTavern"`
  (`/var/lib/SillyTavern`).
- Import + `services.sillytavern.enable = true` in
  `hosts/yifuwuqi/services.nix` (add module to the `imports` list there).

### 3. `modules/services/nginx-proxy.nix` — vhost

```nix
"${yifuwuqiServices.sillytavern.domain}" = {
  useACMEHost = "fufu.land";
  forceSSL = true;
  locations."/" = {
    proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.sillytavern.port}";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_set_header X-Forwarded-Host $host;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_read_timeout 1d;
      proxy_send_timeout 1d;
      client_max_body_size 10M;
      ${restrictedProxyConfig}
    '';
  };
};
```

Long timeouts because Wiro takes seconds; 10M body for image payloads.

### 4. `modules/services/ai/models.nix` — free RAM

Set `qwen3.6-35b-a3b.enable = false` (was `true`): two IQ2_M 35B models
(~13 GiB each) + KV cache on 19.3 GiB RAM is what drives the 52% swap.
Comment: `qwen3.6-35b-abliterated` (:11437) is the companion model.

### 5. Optional — homepage widget for `companion.fufu.land`

## Post-deploy configuration (one-time, in the ST UI)

1. Open `https://companion.fufu.land`, create the local ST account.
2. **API Connections** → Chat Completion (OpenAI) → base URL
   `http://127.0.0.1:11437/v1`, model `qwen3.6-35b-abliterated`.
3. **Extensions → Image Generation** → provider **Custom**:
   - Endpoint: `https://api.wiro.ai/v1/generate`, Authorization
     `Bearer <wiro_api_key>` (use Wiro's free trial credits first —
     50 images on Seedream 5.0 Lite).
   - Request body:
     ```json
     { "model": "seedream-5-lite-uncensored", "prompt": "{{prompt}}", "width": 1024, "height": 1536 }
     ```
   - Response field: `url` (JSONPath).
   - Use `{{char}}`/`{{name}}` placeholders in prompts for character
     consistency (Seedream 5's strength).
4. Import/create a character card; chat; generate.

## Verify

- `nixos-rebuild build --flake .#yifuwuqi` before switching.
- `systemctl status sillytavern llama-cpp-qwen3-6-35b-abliterated`
- `curl -I http://127.0.0.1:8000` and `curl https://companion.fufu.land`
  from a LAN + a VPN client (must succeed) and from outside (must fail).
- End-to-end: one chat turn, one image with trial credit.
- `free -h` before/after — expect swap to drop with the a3b model gone.

## Open items / risks

- Wiro is a small uncensored-API vendor: ToS/uptime volatile — don't prepay
  big bundles.
- If `qwen3.6-35b-a3b` is actually needed by opencode on this host, re-enable
  it and instead trim both models to 8k ctx (RAM, not correctness, is the
  binding constraint).
- ST whitelist mode: confirm the nixpkgs unit's default whitelist includes
  127.0.0.1 (nginx proxies from localhost) — add `whitelist.txt` entry in
  `/var/lib/SillyTavern` if not.
