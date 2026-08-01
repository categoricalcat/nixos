{ pkgs, ... }:

let
  tomlFormat = pkgs.formats.toml { };

  defaultConfig = {
    clear_on_pause = true;
    interval = 2000;
    allowed_players = [ ];

    template = {
      details = "{{{title}}}";
      state = "{{{artist_display}}}";
      large_text = "{{#if album}}{{{album}}}{{#if year}} ({{{year}}}){{/if}}{{/if}}";
      small_text = "{{#if player}}{{{player}}}{{else}}MPRIS{{/if}}";
    };

    time = {
      show = true;
      as_elapsed = false;
    };

    activity_type = {
      use_content_type = true;
      default = "listening";
    };

    cover = {
      file_names = [
        "cover"
        "folder"
        "front"
        "album"
        "art"
      ];
      local_search_depth = 2;
      provider = {
        provider = [
          "musicbrainz"
          "catbox"
        ];
        imgbb = {
          expiration = 86400;
        };
        musicbrainz = {
          min_score = 100;
        };
        catbox = {
          use_litter = false;
          litter_hours = 24;
        };
      };
    };

    player = {
      # Priority: user entries override bundled ones. Fields left unset in a higher-priority entry fall back to lower matches, then [player.default], then built-in defaults. If identity and bus-name differ, an exact user bus-name entry wins.
      default = {
        ignore = false;
        show_icon = false;
        allow_streaming = false;
        # status_display_type = "name"; # or details
        status_display_type = "state";
      };

      chromium = {
        ignore = false;
        allow_streaming = true;
      };

      chrome = {
        ignore = false;
        allow_streaming = true;
      };

      qbz = {
        ignore = false;
        allow_streaming = true;
      };

      qbz-player = {
        ignore = false;
        allow_streaming = true;
      };
    };
  };
in
{
  home.packages = [ pkgs.mprisence ];

  xdg.configFile."mprisence/config.toml".source =
    tomlFormat.generate "mprisence-config" defaultConfig;
}
