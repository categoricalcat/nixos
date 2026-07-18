{ pkgs, nix-ld-libraries, ... }:

pkgs.stdenv.mkDerivation {
  pname = "drum-locker";
  version = "latest";

  # REPLACE THIS PATH WITH YOUR ACTUAL DOWNLOADED ARCHIVE PATH
  # Example: src = /home/yi/Downloads/DrumLocker_Linux.zip;
  src = throw ''
    Audio Assault Drum Locker requires a manual download.
    Please download the Linux VST3 zip from your account,
    and update the `src` attribute in `modules/audio/drum-locker.nix`
    to point to the downloaded file.
  '';

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.unzip
  ];

  buildInputs = nix-ld-libraries;

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    mkdir -p $out/lib/vst3
    # The exact folder name may vary, adjust if necessary after unpacking.
    cp -r *.vst3 $out/lib/vst3/
  '';
}
