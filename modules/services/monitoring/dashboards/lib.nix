let
  panels = import ./panels.nix;

  mkDashboard =
    {
      uid,
      title,
      panels ? [ ],
    }:
    {
      inherit uid title panels;
      schemaVersion = 39;
      tags = [ ];
      timezone = "browser";
      refresh = "10s";
    };

  mkGridPos = x: y: w: h: {
    inherit
      x
      y
      w
      h
      ;
  };

  mkLokiDataLink =
    {
      title ? "View logs in Loki",
      host ? "\${__field.labels.host}",
      unit ? "\${__field.labels.name}",
      queryExtra ? "",
    }:
    let
      query =
        if queryExtra != "" then
          "{host=\\\"${host}\\\",unit=\\\"${unit}\\\"} ${queryExtra}"
        else
          "{host=\\\"${host}\\\",unit=\\\"${unit}\\\"}";
    in
    {
      inherit title;
      url = "/explore?schemaVersion=1&panes={\"a\":{\"datasource\":\"loki\",\"queries\":[{\"datasource\":{\"type\":\"loki\",\"uid\":\"loki\"},\"editorMode\":\"code\",\"expr\":\"${query}\",\"queryType\":\"range\",\"refId\":\"A\"}],\"range\":{\"from\":\"\${__from}\",\"to\":\"\${__to}\"}}}";
      targetBlank = true;
    };

  defaultLokiLinks = [ (mkLokiDataLink { }) ];
in
panels
// {
  inherit
    defaultLokiLinks
    mkDashboard
    mkGridPos
    mkLokiDataLink
    ;
}
