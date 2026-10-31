{ pkgs, lib, ... }:
let
  # sha256 is hex so it can be diffed against the upstream-published digest
  libraries = {
    chords = {
      url = "https://github.com/ldrolez/free-midi-chords/releases/download/v0.20260914/free-midi-chords-20260914.zip";
      sha256 = "153c4d9b186fb240473df5d4cb999502bd4e3264e22d03ff4d0a1c95b1918c8b";
    };
    drums-groove = {
      url = "https://storage.googleapis.com/magentadata/datasets/groove/groove-v1.0.0-midionly.zip";
      sha256 = "651cbc524ffb891be1a3e46d89dc82a1cecb09a57c748c7b45b844c4841dcc1e";
      root = "groove";
    };
    piano-maestro = {
      url = "https://storage.googleapis.com/magentadata/datasets/maestro/v3.0.0/maestro-v3.0.0-midi.zip";
      sha256 = "70470ee253295c8d2c71e6d9d4a815189e35c89624b76d22fce5a019d5dde12c";
      root = "maestro-v3.0.0";
    };
    # no upstream checksum exists; trust-on-first-use
    songs-lakh-clean = {
      url = "http://hog.ee.columbia.edu/craffel/lmd/clean_midi.tar.gz";
      sha256 = "de1bb64cbc0cf35545a05b5c3e786aa6890cfa144edffc4b827ff41bf8c33dc5";
      root = "clean_midi";
    };
  };

  unpack =
    name:
    {
      url,
      sha256,
      root ? "",
    }:
    pkgs.runCommandLocal "midi-${name}" { nativeBuildInputs = [ pkgs.unzip ]; } ''
      mkdir tree
      (cd tree && unpackFile ${pkgs.fetchurl { inherit url sha256; }})
      mv tree/${root} "$out"
    '';
in
{
  # Writable directories in $HOME for user plugins, NAM models and MIDI packs
  systemd.user.tmpfiles.rules = map (dir: "d %h/${dir} 0755 - - - -") [
    ".vst"
    ".vst3"
    ".lv2"
    ".clap"
    ".ladspa"
    "Audio/nam"
    "Audio/ir"
    "Audio/reaper-fxchains"
    "Audio/tapf"
    "Music/midi-library/_user"
  ];

  home.file = lib.mapAttrs' (
    name: entry: lib.nameValuePair "Music/midi-library/${name}" { source = unpack name entry; }
  ) libraries;
}
