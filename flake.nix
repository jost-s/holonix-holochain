{
  description = "Holochain flake";

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

    # lair keystore
    lair = {
      url = "github:holochain/lair";
      # url = "github:jost-s/holonix-lair";
      flake = false;
    };
  };

  # refer to flake-parts docs https://flake.parts/
  outputs = inputs @ { self, nixpkgs, flake-parts, rust-overlay, crane, lair, ... }:
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

          # use rust toolchain specified above
          craneLib = (crane.mkLib pkgs).overrideToolchain rust;

          holochain = craneLib.buildPackage {
            pname = "holochain";
            version = "workspace";
            src = craneLib.cleanCargoSource (craneLib.path ./.);
          };

          lair-keystore =
            let
              sqlFilter = path: _type: builtins.match ".*(sql|md)$" path != null;
              sqlOrCargo = path: type:
                (sqlFilter path type) || (craneLib.filterCargoSources path type);
            in
            craneLib.buildPackage {
              pname = "lair-keystore";
              version = "workspace";
              src = pkgs.lib.cleanSourceWith {
                src = lair;
                filter = sqlOrCargo;
              };
              # perl needed for openssl on all platforms
              buildInputs = [ pkgs.perl ]
                ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
                # additional packages needed for darwin platforms
                pkgs.libiconv
                pkgs.darwin.apple_sdk.frameworks.Security
                # additional packages needed for darwin platforms on x86_64
                pkgs.darwin.apple_sdk_11_0.frameworks.CoreFoundation
              ]);
              doCheck = false;
            };
        in
        {
          packages = {
            inherit holochain;
            inherit lair-keystore;
            inherit rust;
          };

          devShells = {
            default = pkgs.mkShell {
              packages = [
                holochain
                lair-keystore
                rust
              ];
            };
          };
        };
    };
}
