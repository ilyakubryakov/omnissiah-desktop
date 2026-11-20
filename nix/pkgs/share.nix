{ lib, stdenvNoCC, python3, bash, makeWrapper, quickshell }:
let
  python = python3.withPackages (ps: with ps; [
    babel
    google-auth
    google-auth-oauthlib
    msal
    requests
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "oninix-share";
  version = "0.1";
  src = lib.cleanSource ../../desktop;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ python bash ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    share=$out/share/oninix
    mkdir -p $share $out/bin
    cp -r hypr quickshell bin lib themes $share/
    chmod -R u+w $share
    find $share -name '*.pyc' -delete
    patchShebangs $share/bin $share/hypr/scripts $share/themes
    ONINIX_THEME_ROOT=$share HOME=$TMPDIR XDG_STATE_HOME=$TMPDIR/state \
      ${bash}/bin/bash $share/bin/oninix-theme render-only >/dev/null
    for tool in $share/bin/*; do
      ln -s $tool $out/bin/$(basename $tool)
    done
    makeWrapper ${quickshell}/bin/quickshell $out/bin/oninix-shell \
      --add-flags "-p $share/quickshell/shell.qml"
    runHook postInstall
  '';
}
