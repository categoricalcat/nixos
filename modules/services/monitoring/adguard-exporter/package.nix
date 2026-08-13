{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule {
  pname = "adguard-exporter";
  version = "unstable-2026-08-10";

  src = fetchFromGitHub {
    owner = "znand-dev";
    repo = "adguardexporter";
    rev = "9dba360e6cced90da8de839e206518dfa37a91af";
    hash = "sha256-g+Al3ZqCdEbmnSdMXeg6Ibh87yZi/Kuy6E5CfW45P4Y=";
  };

  vendorHash = "sha256-s4DRqblNWZvzsWcU9vWXSJjssz5UvePlDY99kc8LP9k=";

  meta = with lib; {
    description = "Prometheus exporter for AdGuard Home DNS statistics";
    homepage = "https://github.com/znand-dev/adguardexporter";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
