let
  yaml = builtins.readFile ./theme.yaml;

  lines = builtins.filter (x: builtins.isString x && builtins.match "^base.*" x != null) (
    builtins.split "\n" yaml
  );

  # Matches formats like `base00: "020203"` or `base00: 020203`
  parseLine =
    l:
    let
      m = builtins.match "(base[0-9a-fA-F]+): *\"?([0-9a-fA-F]+)\"?.*" l;
    in
    {
      name = builtins.elemAt m 0;
      value = builtins.elemAt m 1;
    };
in
builtins.listToAttrs (map parseLine lines)
