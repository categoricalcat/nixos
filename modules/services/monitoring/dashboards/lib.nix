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
      mappings ? [ ],
      thresholds ? null,
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
          inherit unit mappings;
        }
        // (
          if thresholds != null then
            {
              thresholds = {
                mode = "absolute";
                steps = thresholds;
              };
            }
          else
            { }
        )
        // (if links != [ ] then { inherit links; } else { });
      };
    };

  mkBarGauge =
    {
      title,
      expr,
      gridPos,
      legendFormat ? "{{instance}}",
      unit ? "none",
      min ? 0,
      max ? 10,
      thresholds ? [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 4.0;
        }
        {
          color = "red";
          value = 7.0;
        }
      ],
      links ? [ ],
      orientation ? "horizontal",
      displayMode ? "gradient",
    }:
    {
      type = "bargauge";
      inherit title gridPos;
      targets = [
        {
          inherit expr legendFormat;
          format = "time_series";
          instant = true;
        }
      ];
      options = {
        inherit orientation displayMode;
        showUnfilled = true;
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
      };
      fieldConfig = {
        defaults = {
          inherit unit min max;
          thresholds = {
            mode = "absolute";
            steps = thresholds;
          };
          mappings = [ ];
        }
        // (if links != [ ] then { inherit links; } else { });
      };
    };

  mkTable =
    {
      title,
      expr,
      gridPos,
      transformations ? [ ],
      overrides ? [ ],
      links ? [ ],
      sortBy ? [ ],
    }:
    {
      type = "table";
      inherit title gridPos transformations;
      targets = [
        {
          inherit expr;
          format = "table";
          instant = true;
        }
      ];
      options = {
        cellHeight = "sm";
        footer = {
          countRows = false;
          enablePagination = true;
          show = false;
        };
        showHeader = true;
      }
      // (if sortBy != [ ] then { inherit sortBy; } else { });
      fieldConfig = {
        defaults = {
          custom = {
            align = "auto";
            cellOptions = {
              type = "auto";
            };
            inspect = false;
          };
        }
        // (if links != [ ] then { inherit links; } else { });
        inherit overrides;
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
    mkBarGauge
    mkTable
    mkStateTimeline
    mkLokiDataLink
    ;
}
