{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      systems = [
        "x86_64-linux"
      ];
      perSystem =
        { pkgs, ... }:
        let
          gems = pkgs.bundlerEnv {
            name = "gemset";
            ruby = pkgs.ruby;
            gemdir = ./.;
          };
        in
        {
          formatter = pkgs.nixfmt;

          packages.gems = gems;

          # used by nix shell and nix develop
          devShells.default =
            with pkgs;
            mkShell {
              shellHook = ''
                # Required to work with platform specific gems
                export BUNDLE_FORCE_RUBY_PLATFORM=true;
              '';

              buildInputs = [
                bundix
                gems
                gems.wrappedRuby
              ];
            };
        };
    });
}
