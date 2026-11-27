{ hyprlandPlugins, fetchFromGitHub, cmake, lib, hyprland }:
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "titlebars";
  version = "0.4.0";
  src = fetchFromGitHub {
    owner = "omacom";
    repo = "omarchy-hyprland-titlebars";
    rev = "929ed753a667dd7d13688e0c8b2d5c930f1babda";
    hash = "sha256-Y1fZCyhTxCb3x7xJ2TSmVN5bKZY+u+ObjYe76/yoj5k=";
  };
  inherit hyprland;
  nativeBuildInputs = [ cmake ];
  postPatch = ''
    substituteInPlace main.cpp --replace-fail '  HyprlandAPI::reloadConfig();' ""
  '';
  meta = {
    description = "Titlebars for floating workspaces (Omarchy fork of hyprbars)";
    homepage = "https://github.com/omacom/omarchy-hyprland-titlebars";
    license = [ lib.licenses.bsd3 lib.licenses.mit ];
  };
}
