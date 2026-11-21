{ lib, stdenvNoCC, makeWrapper, python3, gum, disko, pciutils, util-linux, cryptsetup, curl, networkmanager, nixos-install-tools, source ? "" }:
stdenvNoCC.mkDerivation {
  pname = "oninix-installer";
  version = "0.1";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/share/oninix-installer $out/bin
    cp ${./oninix-installer.py} $out/share/oninix-installer/oninix-installer.py
    cp -r ${../template} $out/share/oninix-installer/template
    makeWrapper ${python3}/bin/python3 $out/bin/oninix-installer \
      --run 'if [ "$EUID" -ne 0 ]; then exec /run/wrappers/bin/sudo -- "$0" "$@"; fi' \
      --add-flags "-I $out/share/oninix-installer/oninix-installer.py" \
      --set ONINIX_TEMPLATE $out/share/oninix-installer/template \
      --set ONINIX_SOURCE "${source}" \
      --prefix PATH : ${lib.makeBinPath [ gum disko pciutils util-linux cryptsetup curl networkmanager nixos-install-tools ]}
  '';
  meta.mainProgram = "oninix-installer";
}
