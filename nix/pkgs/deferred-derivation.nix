{ runCommand, nix, gzip, python3 }:
package:
let
  drv = builtins.unsafeDiscardOutputDependency package.drvPath;
in
runCommand "${package.name}-recipe.gz" {
  nativeBuildInputs = [ nix gzip python3 ];
} ''
  staged="$TMPDIR/recipe-store"
  mkdir -p "$staged/nix/store"
  python3 ${./pack-derivation.py} ${drv} "$staged/nix/store" > registration
  export NIX_REMOTE="$staged"
  nix-store --register-validity < registration
  nix-store --export $(nix-store --query --requisites ${drv}) | gzip -n > "$out"
''
