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
          custom = {
            drawStyle = "line";
            lineInterpolation = "linear";
            lineWidth = 1;
            fillOpacity = 10;
          };
        };
      };
    };

  mkStat =
    {
      title,
      expr,
      gridPos,
      legendFormat ? "{{instance}}",
      unit ? "none",
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
        };
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
        };
      };
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
    ;
}
