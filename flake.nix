{
  description = "kai.blu.cx: Kai's home page";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # The Roc nightly roc-signals 0.5.0 was built and tested with, from
      # Roc's own downloads.
      rocVersion = "nightly-2026-11-11-7679cc5";
      rocDownloads = {
        x86_64-linux = { name = "linux_x86_64"; hash = "sha256-RFPhnA2EyMBrndbSDv/qzYFR3mIZEz08udNhI1WpsYk="; };
        aarch64-linux = { name = "linux_arm64"; hash = "sha256-EgZtWaouXfY4FbdK/DbYllCtFbCu5bKe7VEOKrL7aWo="; };
        aarch64-darwin = { name = "macos_apple_silicon"; hash = "sha256-1U8axlfhAcNmSwXyoHDLOl3ayeD4ybhpKZXQqD4xMN8="; };
      };
      roc = pkgs:
        let
          download = rocDownloads.${pkgs.stdenv.hostPlatform.system};
          date = nixpkgs.lib.removePrefix "nightly-" rocVersion;
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "roc";
          version = rocVersion;
          src = pkgs.fetchurl {
            url = "https://github.com/roc-lang/nightlies/releases/download/${rocVersion}/roc_nightly-${download.name}-${date}.tar.gz";
            inherit (download) hash;
          };
          sourceRoot = ".";
          dontStrip = true;
          installPhase = ''
            mkdir -p $out/bin
            cp "$(find . -type f -name roc | head -1)" $out/bin/roc
          '';
        };
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell { packages = [ (roc pkgs) pkgs.jq pkgs.pandoc pkgs.rsync pkgs.curl ]; };
      });
    };
}
