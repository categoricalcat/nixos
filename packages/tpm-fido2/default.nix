{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  fprintd,
}:

buildGoModule {
  pname = "tpm-fido2";
  version = "unstable-2024-04-12";

  src = fetchFromGitHub {
    owner = "mc256";
    repo = "tpm-fido2-thinkpad-linux";
    rev = "49222c60dbbf0c5ec4356240cbd92789e41945da";
    hash = "sha256-eC5nsIYm3gLfs2vPU6Bo2L1D0mNWT2gOTq2aBe39jT0=";
  };

  vendorHash = "sha256-Q/FapUvEW/i7acfIPtlJqlTQ4/LKCeUJa3gU7xMX/C4=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ fprintd ];

  meta = with lib; {
    description = "Virtual FIDO2 security key using TPM and Fingerprint";
    homepage = "https://github.com/mc256/tpm-fido2-thinkpad-linux";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
