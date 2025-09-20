{ stdenv, lib, pkgs, packageIndex, arduinoPackages }:

let
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

            src = pkgs.fetchurl ({
              url = system.url;
            } // (convertHash system.checksum));

            nativeBuildInputs = [ pkgs.unzip ];

            installPhase = let
              dirName = "packages/${platformName}/tools/${name}/${version}";
            in ''
              runHook preInstall

              mkdir -p "$out/${dirName}"
              cp -R * "$out/${dirName}/"

              runHook postInstall
            '';

          };
    }) versions)) (lib.groupBy ({ name, ... }: name) tools);
  }) packageIndex.packages);
    
  # Platform are installed in $platform_name/hardware/$architecture/$version
  platforms = lib.listToAttrs (lib.map ({ name, platforms, ... }: {
    inherit name;
    value = lib.mapAttrs (architecture: versions: lib.listToAttrs (lib.map ({version, url, checksum, toolsDependencies ? [], ...}: {
      name = version;
      value = let
        package = stdenv.mkDerivation {
          pname = "${name}-${architecture}";
          inherit version;

          src = pkgs.fetchurl ({
            url = url;
          } // (convertHash checksum));

          nativeBuildInputs = [ pkgs.unzip ];

          installPhase = let
            dirName = "packages/${name}/hardware/${architecture}/${version}";
          in
            ''
            runHook preInstall

            mkdir -p "$out/${dirName}"
            cp -R * "$out/${dirName}/"

            runHook postInstall
          '';
        };

      in pkgs.symlinkJoin {
        name = package.pname;
        paths = [ package ] ++ (lib.map ({packager, name, version}: arduinoPackages.tools.${packager}.${name}.${version}) toolsDependencies);
      };
    }) versions)) (lib.groupBy ({ architecture, ... }: architecture) platforms);
  }) packageIndex.packages);
in
{
  inherit tools platforms;
}
