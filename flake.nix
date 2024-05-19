{
  description = "Developer environment shells to build Holochain apps.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # utility to iterate over multiple target platforms
    flake-parts.url = "github:hercules-ci/flake-parts";

    # lib to build nix packages from rust crates
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # rustup, rust and cargo
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # refer to flake-parts docs https://flake.parts/
  outputs = inputs @ { self, nixpkgs, flake-parts, rust-overlay, crane, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-linux" "x86_64-darwin" "aarch64-linux" ];

      perSystem = { config, pkgs, system, ... }:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };

          rust = (pkgs.rust-bin.stable."1.78.0".default.override
            {
              targets = [ "wasm32-unknown-unknown" ];
            });

          craneLib = crane.mkLib pkgs;

          holochain = craneLib.buildPackage {
            pname = "holochain";
            version = "workspace";
            src = craneLib.cleanCargoSource (craneLib.path ./.);
          };
        in
        {
          packages = {
            inherit holochain;
            inherit rust;
          };
        };
    };
}
