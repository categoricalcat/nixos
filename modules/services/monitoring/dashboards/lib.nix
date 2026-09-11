_:
let
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

  mkTimeseries =
    {
      title,
      expr,
      gridPos,
      legendFormat ? "{{instance}}",
      unit ? "none",
      links ? [ ],
    }:
    {
      type = "timeseries";
      inherit title gridPos;
      targets = [
        {
          inherit expr legendFormat;
          format = "time_series";
        }
      ];
      fieldConfig = {
        defaults = {
          inherit unit;
          custom = {
            drawStyle = "line";
            lineInterpolation = "linear";
            lineWidth = 1;
            fillOpacity = 10;
          };
        }
        // (if links != [ ] then { inherit links; } else { });
      };
    };

  mkStat =
    {
      title,
      expr,
      gridPos,
      legendFormat ? "{{instance}}",
      unit ? "none",
      links ? [ ],
    }:
    {
      type = "stat";
      inherit title gridPos;
      targets = [
        {
          inherit expr legendFormat;
          format = "time_series";
        }
      ];
      fieldConfig = {
        defaults = {
          inherit unit;
          mappings = [ ];
        }
        // (if links != [ ] then { inherit links; } else { });
      };
    };

  mkGauge =
    {
      title,
      expr,
      gridPos,
      legendFormat ? "{{instance}}",
      unit ? "none",
      min ? 0,
      max ? 100,
    }:
    {
      type = "gauge";
      inherit title gridPos;
      targets = [
        {
          inherit expr legendFormat;
          format = "time_series";
        }
      ];
      fieldConfig = {
        defaults = {
          inherit unit min max;
          mappings = [ ];
        };
      };
    };

  mkStateTimeline =
    {
      title,
      expr,
      gridPos,
      legendFormat ? "{{instance}}",
      links ? [ ],
    }:
    {
      type = "state-timeline";
      inherit title gridPos;
      targets = [
        {
          inherit expr legendFormat;
          format = "time_series";
        }
      ];
      fieldConfig = {
        defaults = {
          custom = {
            rowHeight = 0.9;
          };
          mappings = [
            {
              options = {
                "0" = {
                  text = "Inactive";
                  color = "red";
                };
                "1" = {
                  text = "Active";
                  color = "green";
                };
                "2" = {
                  text = "Failed";
                  color = "red";
                };
                "3" = {
                  text = "Activating";
                  color = "orange";
                };
                "4" = {
                  text = "Deactivating";
                  color = "orange";
                };
              };
              type = "value";
            }
          ];
        }
        // (if links != [ ] then { inherit links; } else { });
      };
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

in
{
  inherit
    mkDashboard
    mkGridPos
    mkTimeseries
    mkStat
    mkGauge
    mkStateTimeline
    mkLokiDataLink
    ;
}
