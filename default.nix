let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.05";
  pkgs = import nixpkgs { config = {}; overlays = []; };
in
{
  polygon-bor = pkgs.callPackage ./polygon-bor.nix { inherit (pkgs.darwin) IOKit libobjc; };
}