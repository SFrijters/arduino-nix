{ lib }:
let
  alt = a: b: if a == null then b else a;
in
rec {
  latestVersion =
    attrs:
    (lib.head (
      lib.sort (a: b: (lib.strings.compareVersions a.version b.version) == 1) (
        lib.attrValues (lib.mapAttrs (version: value: { inherit version value; }) attrs)
      )
    )).value;

  # From tools.go in arduino-cli
  # regexpLinuxArm   = regexp.MustCompile("arm.*-linux-gnueabihf")
  # regexpLinuxArm64 = regexp.MustCompile("(aarch64|arm64)-linux-gnu")
  # regexpLinux64    = regexp.MustCompile("x86_64-.*linux-gnu")
  # regexpLinux32    = regexp.MustCompile("i[3456]86-.*linux-gnu")
  # regexpWindows32  = regexp.MustCompile("i[3456]86-.*(mingw32|cygwin)")
  # regexpWindows64  = regexp.MustCompile("(amd64|x86_64)-.*(mingw32|cygwin)")
  # regexpMac64      = regexp.MustCompile("x86_64-apple-darwin.*")
  # regexpMac32      = regexp.MustCompile("i[3456]86-apple-darwin.*")
  # regexpMacArm64   = regexp.MustCompile("arm64-apple-darwin.*")
  # regexpFreeBSDArm = regexp.MustCompile("arm.*-freebsd[0-9]*")
  # regexpFreeBSD32  = regexp.MustCompile("i?[3456]86-freebsd[0-9]*")
  # regexpFreeBSD64  = regexp.MustCompile("amd64-freebsd[0-9]*")

  selectSystem =
    system: systems:
    if system == "aarch64-darwin" then
      alt (lib.findFirst ({ host, ... }: (lib.match "arm64-apple-darwin.*" host) != null) null systems) (
        selectSystem "x86_64-darwin" systems
      )
    else if system == "x86_64-darwin" then
      alt (lib.findFirst ({ host, ... }: (lib.match "x86_64-apple-darwin.*" host) != null) null systems) (
        selectSystem "i686-darwin" systems
      )
    else if system == "i686-darwin" then
      lib.findFirst ({ host, ... }: (lib.match "i[3456]86-apple-darwin.*" host) != null) null systems
    else if system == "aarch64-linux" then
      # tools.go uses regexp.MatchString which will also return true for substring matches, so we add a .* to the regex
      lib.findFirst ({ host, ... }: (lib.match "(aarch64|arm64)-linux-gnu.*" host) != null) null systems
    else if system == "x86_64-linux" then
      # also add a .* to the regex here though it is not necessary in the current dataset (March 2024)
      lib.findFirst ({ host, ... }: (lib.match "x86_64-.*linux-gnu.*" host) != null) null systems
    else
      null;
  convertHash =
    hash:
    let
      m = lib.match "(SHA-256|SHA-1|MD5):(.*)" hash;
      algo = lib.elemAt m 0;
      h = lib.elemAt m 1;
    in
    if m == null then
      throw "Unsupported hash format ${hash}"
    else if algo == "SHA-256" then
      { sha256 = h; }
    else if algo == "SHA-1" then
      { sha1 = h; }
    else
      { md5 = h; };
}
