{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    pnpm
    eslint
    typescript
    npm-check-updates
  ];

  home.activation.cloneDotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/the.files/.git" ]; then
      echo "Copying the.files repository from flake input..."
      $DRY_RUN_CMD cp -r --no-preserve=mode,ownership ${inputs.thefiles} $HOME/the.files
      $DRY_RUN_CMD chmod -R u+w $HOME/the.files
    else
      echo "the.files repository already exists"
    fi
  '';
}
