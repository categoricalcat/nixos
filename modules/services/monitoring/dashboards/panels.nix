let
  withLinks = links: attrs: attrs // (if links == [ ] then { } else { inherit links; });

  mkPrometheusTarget =
    {
      expr,
      legendFormat ? null,
      format ? "time_series",
      instant ? null,
    }:
    {
      inherit expr format;
    }
    // (if legendFormat == null then { } else { inherit legendFormat; })
    // (if instant == null then { } else { inherit instant; });

  mkAbsoluteThresholds = steps: {
    mode = "absolute";
    inherit steps;
  };

  mkThresholdSteps =
    {
      orange ? null,
      red ? null,
    }:
    builtins.filter (step: step != null) [
      {
        color = "green";
        value = null;
      }
      (
        if orange == null then
          null
        else
          {
            color = "orange";
            value = orange;
          }
      )
      (
        if red == null then
          null
        else
          {
            color = "red";
            value = red;
          }
      )
    ];

  alertThresholds = mkThresholdSteps { red = 1; };

  mkValueMappings = options: [
    {
      type = "value";
      inherit options;
    }
  ];

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
      targets = [ (mkPrometheusTarget { inherit expr legendFormat; }) ];
      fieldConfig = {
        defaults = withLinks links {
          inherit unit;
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
      links ? [ ],
      mappings ? [ ],
      thresholds ? null,
    }:
    {
      type = "stat";
      inherit title gridPos;
      targets = [ (mkPrometheusTarget { inherit expr legendFormat; }) ];
      fieldConfig = {
        defaults = withLinks links (
          {
            inherit unit mappings;
          }
          // (
            if thresholds != null then
              {
                thresholds = mkAbsoluteThresholds thresholds;
              }
            else
              { }
          )
        );
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
      thresholds ? mkThresholdSteps {
        orange = 4.0;
        red = 7.0;
      },
      links ? [ ],
      orientation ? "horizontal",
      displayMode ? "gradient",
    }:
    {
      type = "bargauge";
      inherit title gridPos;
      targets = [
        (mkPrometheusTarget {
          inherit expr legendFormat;
          instant = true;
        })
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
        defaults = withLinks links {
          inherit unit min max;
          thresholds = mkAbsoluteThresholds thresholds;
          mappings = [ ];
        };
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
        (mkPrometheusTarget {
          inherit expr;
          format = "table";
          instant = true;
        })
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
        defaults = withLinks links {
          custom = {
            align = "auto";
            cellOptions = {
              type = "auto";
            };
            inspect = false;
          };
        };
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
      targets = [ (mkPrometheusTarget { inherit expr legendFormat; }) ];
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
      targets = [ (mkPrometheusTarget { inherit expr legendFormat; }) ];
      fieldConfig = {
        defaults = withLinks links {
          custom = {
            rowHeight = 0.9;
          };
          mappings = mkValueMappings {
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
        };
      };
    };
in
{
  inherit
    alertThresholds
    mkBarGauge
    mkGauge
    mkStateTimeline
    mkStat
    mkTable
    mkThresholdSteps
    mkTimeseries
    mkValueMappings
    ;
}
