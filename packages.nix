{ fetchzip, stdenv, lib, packageIndex, pkgsBuildHost, pkgs, arduinoPackages }:

let
  inherit (pkgsBuildHost.xorg) lndir;
  inherit (pkgs.callPackage ./lib.nix {}) selectSystem convertHash;

  # Tools are installed in $platform_name/tools/$name/$version
  tools = lib.listToAttrs (lib.map ({ name, tools, ... }: {
    inherit name;
    value = let platformName = name; in lib.mapAttrs (_: versions: lib.listToAttrs (lib.map ({name, version, systems, ...}: {
      name = version;
      value = let
        system = selectSystem stdenv.hostPlatform.system systems;
      in
        if system == null then
          throw "Unsupported platform ${stdenv.hostPlatform.system}"
        else
          stdenv.mkDerivation {
            pname = "${platformName}-${name}";
            inherit version;

            dirName = "packages/${platformName}/tools/${name}/${version}";
            installPhase = ''
              mkdir -p "$out/$dirName"
              cp -R * "$out/$dirName/"
            '';
            nativeBuildInputs = [ pkgs.unzip ];
            src = pkgs.fetchurl ({
              url = system.url;
            } // (convertHash system.checksum));
          };
    }) versions)) (lib.groupBy ({ name, ... }: name) tools);
  }) packageIndex.packages);
    
  # Platform are installed in $platform_name/hardware/$architecture/$version
  platforms = lib.listToAttrs (lib.map ({ name, platforms, ... }: {
    inherit name;
    value = lib.mapAttrs (architecture: versions: lib.listToAttrs (lib.map ({version, url, checksum, toolsDependencies ? [], ...}: {
      name = version;
      value = stdenv.mkDerivation {
        pname = "${name}-${architecture}";
        inherit version;
        dirName = "packages/${name}/hardware/${architecture}/${version}";

        toolsDependencies = lib.map ({packager, name, version}: arduinoPackages.tools.${packager}.${name}.${version}) toolsDependencies;
        passAsFile = [ "toolsDependencies" ];
        installPhase = ''
          runHook preInstall

          mkdir -p "$out/$dirName"
          cp -R * "$out/$dirName/"

          for i in $(cat $toolsDependenciesPath); do
            ${lndir}/bin/lndir -silent $i $out
          done

          runHook postInstall
        '';
        nativeBuildInputs = [ pkgs.unzip ];
        src = pkgs.fetchurl ({
          url = url;
        } // (convertHash checksum));
      };
    }) versions)) (lib.groupBy ({ architecture, ... }: architecture) platforms);
  }) packageIndex.packages);
in
{
  inherit tools platforms;
}
