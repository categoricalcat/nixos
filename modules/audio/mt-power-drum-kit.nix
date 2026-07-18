{ pkgs, nix-ld-libraries, ... }:

pkgs.stdenv.mkDerivation {
  pname = "mt-power-drum-kit";
  version = "2.1.5";

  src = pkgs.fetchzip {
    url = "https://cdn2.resources.manda-audio.com/DOWNLOADS/products/mtpdk2_free/2.1.5/MTPDK-2.1.5.0-VST3-64bit-Linux-FULL.zip";
    sha256 = "0g7l95z15xis9dddwyw6jsi5nbkpwv6amyhnsvj5xs4g21g19p0l";
    stripRoot = false;
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];

  buildInputs = nix-ld-libraries;

  installPhase = ''
    mkdir -p $out/lib/vst3
    cp -r MT-PowerDrumKit.vst3 $out/lib/vst3/
  '';
}
