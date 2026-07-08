let
  yaml = builtins.readFile ./modules/theme.yaml;

  lines = builtins.filter (x: builtins.isString x && builtins.match "^[a-zA-Z0-9]+:.*" x != null) (
    builtins.split "\n" yaml
  );

  parseLine =
    l:
    let
      m = builtins.match "^([a-zA-Z0-9]+): *\"?([^\"]+)\"?.*" l;
    in
    {
      name = builtins.elemAt m 0;
      value = builtins.elemAt m 1;
    };
in
builtins.listToAttrs (map parseLine lines)
