{ fetchzip, stdenv, lib, libraryIndex, pkgsBuildHost, pkgs, arduinoPackages }:

let
  inherit (pkgs.callPackage ./lib.nix {}) convertHash;
    
  libraries = lib.mapAttrs (name: versions: lib.listToAttrs (lib.map ({version, url, checksum, ...}: {
    name = version;
    value = stdenv.mkDerivation {
      pname = name;
      inherit version;

      src = pkgs.fetchurl ({
        url = url;
      } // (convertHash checksum));

      nativeBuildInputs = [ pkgs.unzip ];

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/libraries/$pname"
        cp -R * "$out/libraries/$pname/"

        runHook postInstall
      '';

    };
  }) versions)) (lib.groupBy ({ name, ... }: name) libraryIndex.libraries);
in
  libraries
