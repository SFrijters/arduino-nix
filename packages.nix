{
  fetchzip,
  stdenv,
  lib,
  packageIndex,
  pkgsBuildHost,
  pkgs,
  arduinoPackages,
}:

with builtins;
let
  inherit (pkgsBuildHost.xorg) lndir;
  inherit (pkgs.callPackage ./lib.nix { }) selectSystem convertHash;

  # Tools are installed in $platform_name/tools/$name/$version
  tools = listToAttrs (
    map (
      { name, tools, ... }:
      {
        inherit name;
        value =
          let
            platformName = name;
          in
          mapAttrs (
            _: versions:
            listToAttrs (
              map (
                {
                  name,
                  version,
                  systems,
                  ...
                }:
                {
                  name = version;
                  value =
                    let
                      system = selectSystem stdenv.hostPlatform.system systems;
                    in
                    if system == null then
                      throw "Unsupported platform ${stdenv.hostPlatform.system}"
                    else
                      stdenv.mkDerivation {
                        pname = "${platformName}-${name}";
                        inherit version;

                        src = fetchurl (
                          {
                            url = lib.traceVal system.url;
                          }
                          // (convertHash system.checksum)
                        );

                        nativeBuildInputs = [ pkgs.unzip ];

                        installPhase = let
                          dirName = "packages/${platformName}/tools/${name}/${version}";
                        in
                          ''
                          mkdir -p "$out/${dirName}"
                          cp -R * "$out/${dirName}/"
                        '';
                      };
                }
              ) versions
            )
          ) (groupBy ({ name, ... }: name) tools);
      }
    ) packageIndex.packages
  );

  # Platform are installed in $platform_name/hardware/$architecture/$version
  platforms = listToAttrs (
    map (
      { name, platforms, ... }:
      {
        inherit name;
        value = mapAttrs (
          architecture: versions:
          listToAttrs (
            map (
              {
                version,
                url,
                checksum,
                toolsDependencies ? [ ],
                ...
              }:
              {
                name = version;
                value = let

                  toolsDependencies' = map (
                    {
                      packager,
                      name,
                      version,
                    }:
                    arduinoPackages.tools.${packager}.${name}.${version}
                  ) toolsDependencies;

                  platform = stdenv.mkDerivation {
                    pname = "${name}-${architecture}";
                    inherit version;

                    src = fetchurl (
                      {
                        url = lib.traceVal url;
                      }
                      // (convertHash checksum)
                    );

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
                in
                  pkgs.symlinkJoin {
                    name = "${name}-${architecture}";
                    paths = [ platform ] ++ toolsDependencies';
                  };
              }
            ) versions
          )
        ) (groupBy ({ architecture, ... }: architecture) platforms);
      }
    ) packageIndex.packages
  );
in
{
  inherit tools platforms;
}
