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

          lair-keystore = craneLib.buildPackage {
            pname = "lair-keystore";
            version = "workspace";
            src = craneLib.cleanCargoSource lair;

            # buildInputs = [ pkgs.openssl ] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin
            #   (with pkgs.darwin.apple_sdk_11_0.frameworks; [
            #     AppKit
            #     CoreFoundation
            #     CoreServices
            #     Security
            #   ]));

            # nativeBuildInputs = [ pkgs.perl pkgs.pkg-config ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin
            #   (with pkgs; [ xcbuild libiconv ]);
            buildInputs = [ ] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.libiconv
              pkgs.perl
              # pkgs.darwin.apple_sdk.frameworks.Security
              # pkgs.darwin.apple_sdk.frameworks.AppKit
              # pkgs.darwin.apple_sdk.frameworks.CoreFoundation
              # pkgs.darwin.apple_sdk.frameworks.CoreServices
              # pkgs.xcbuild
              # pkgs.pkg-config
            ]);
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
