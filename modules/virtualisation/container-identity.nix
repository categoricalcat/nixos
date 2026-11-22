# Pure container identity extractor shared by the static config contract
# (nix/checks.nix) and the runtime security-monitor audit
# (modules/services/monitoring/security-monitor/default.nix).
{ lib }:
let
  toNum = s: if builtins.isString s && builtins.match "[0-9]+" s != null then lib.toInt s else null;
in
c:
let
  parts = lib.splitString ":" c.user;
in
if (c.user or null) != null then
  {
    uid = toNum (builtins.head parts);
    gid = if lib.length parts > 1 then toNum (lib.elemAt parts 1) else null;
    rootReason = c.rootReason or null;
  }
else
  {
    uid = toNum (c.environment.PUID or null);
    gid = toNum (c.environment.PGID or null);
    rootReason = c.rootReason or null;
  }
