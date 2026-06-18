let
  keys = import ./keys.nix;
  yaml = ''
    creation_rules:
      - path_regex: (/persist/keys/sops|secrets)/.*\.yaml$
        key_groups:
          - age:
    ${builtins.concatStringsSep "\n" (map (k: "          - ${k}") keys.sopsAgeRecipients)}
  '';
in
yaml
