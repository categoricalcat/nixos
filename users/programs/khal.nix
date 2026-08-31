{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf (config.host.desktopEnvironment != null) {
    accounts.calendar = {
      basePath = "${config.home.homeDirectory}/.local/share/calendars";
      accounts.personal = {
        primary = true;
        khal = {
          enable = true;
          type = "calendar";
        };
      };
    };

    programs.khal = {
      enable = true;
      locale = {
        firstweekday = 0;
        timeformat = "%H:%M";
        dateformat = "%Y-%m-%d";
        longdateformat = "%Y-%m-%d";
        datetimeformat = "%Y-%m-%d %H:%M";
        longdatetimeformat = "%Y-%m-%d %H:%M";
      };
      settings = {
        view = {
          agenda_event_format = "{calendar-color}{cancelled}{start-end-time-style} {title}{repeat-symbol}{reset}";
        };
      };
    };

    home.file.".local/share/calendars/personal/.keep".text = "";
  };
}
