{ runCommand }:
runCommand "oninix-share" { } ''
  mkdir -p $out/share/oninix
  cp -r ${../../desktop/hypr} $out/share/oninix/hypr
''
