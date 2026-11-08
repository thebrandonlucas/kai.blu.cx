{
  description = "cow";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems
          (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # nix develop
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.cowsay pkgs.fortune ];
        };
      });

      # nix run .#wisdom
      apps = forAllSystems (pkgs: {
        wisdom = {
          type = "app";
          program = toString (pkgs.writeShellScript "wisdom" ''
            ${pkgs.fortune}/bin/fortune | ${pkgs.cowsay}/bin/cowsay
          '');
        };
      });
    };
}
