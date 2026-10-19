{ lib, ... }:

let
  schema = import ./schema.nix { inherit lib; };
  shellCommands = import ./shell-commands.nix { inherit lib; };
  mango = import ./mango.nix {
    inherit lib;
    inherit (schema) bindings;
    inherit shellCommands;
  };
  niri = import ./niri.nix {
    inherit lib;
    inherit (schema) bindings;
    inherit shellCommands;
  };
  gnome = import ./gnome.nix { inherit lib; };
in
{
  inherit (schema) bindings;
  inherit (mango) generateMangoConfig;
  inherit (niri) toNiriKey getNiriBinds generateDmsBindsKdl;
  inherit (gnome) toGnomeKey;
  inherit shellCommands;
}
