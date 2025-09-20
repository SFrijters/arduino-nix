{ lib, pkgs }:
let
  wrap =
    {
      packages ? [ ],
      libraries ? [ ],
    }:
    let
      inherit (pkgs.callPackage ./lib.nix { }) latestVersion;

      builtinPackages = (lib.map latestVersion (lib.attrValues pkgs.arduinoPackages.tools.builtin));

      userPath = pkgs.symlinkJoin {
        name = "arduino-libraries";
        paths = libraries;
      };

      dataPath = pkgs.symlinkJoin {
        name = "arduino-data";
        paths =
          builtinPackages
          ++ packages
          ++ [
            # Add some dummy files to keep the CLI happy
            (pkgs.writeTextDir "inventory.yaml" (lib.strings.toJSON { }))
            (pkgs.writeTextDir "package_index.json" (lib.strings.toJSON { packages = [ ]; }))
            (pkgs.writeTextDir "library_index.json" (lib.strings.toJSON { libraries = [ ]; }))
          ];
        postBuild = ''
          mkdir -p $out/staging
        '';
      };
    in
    pkgs.runCommand "arduino-cli-wrapped"
      {
        buildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = "arduino-cli";
        passthru = {
          inherit dataPath userPath;
        };
      }
      ''
        makeWrapper ${pkgs.arduino-cli}/bin/arduino-cli $out/bin/arduino-cli --set ARDUINO_UPDATER_ENABLE_NOTIFICATION false --set ARDUINO_DIRECTORIES_DATA ${dataPath} --set ARDUINO_DIRECTORIES_USER ${userPath}
      '';
in
lib.makeOverridable wrap
