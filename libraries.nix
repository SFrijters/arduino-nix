{ fetchzip, stdenv, lib, libraryIndex, pkgsBuildHost, pkgs, arduinoPackages }:

with builtins;
let
  inherit (pkgs.callPackage ./lib.nix {}) convertHash;
    
  libraries = mapAttrs (name: versions: listToAttrs (map ({version, url, checksum, ...}: {
    name = version;
    value = stdenv.mkDerivation {
      pname = name;
      inherit version;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/libraries/$pname"
        cp -R * "$out/libraries/$pname/"

        runHook postInstall
      '';
      nativeBuildInputs = [ pkgs.unzip ];
      src = pkgs.fetchurl ({
        url = url;
      } // (convertHash checksum));
    };
  }) versions)) (groupBy ({ name, ... }: name) libraryIndex.libraries);
in
  libraries
