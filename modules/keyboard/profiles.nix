let
  profiles = {
    us = {
      layout = "us";
      variant = "intl";
      keyMap = "us-acentos";
      fcitxLayout = "us-intl";
    };
    br = {
      layout = "br";
      variant = "thinkpad";
      keyMap = "br-abnt2";
      fcitxLayout = "br-thinkpad";
    };
  };
in
{
  inherit profiles;

  order =
    primary: [ primary ] ++ builtins.filter (name: name != primary) (builtins.attrNames profiles);
}
