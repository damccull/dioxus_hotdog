{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay.url = "github:oxalica/rust-overlay";
    surrealdb-gh.url = "github:surrealdb/surrealdb/v2.0.4";
  };
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem =
        {
          config,
          self',
          pkgs,
          lib,
          system,
          ...
        }:
        let
          androidSdk =
            let
              androidComposition = pkgs.androidenv.composeAndroidPackages {
                cmdLineToolsVersion = "13.0";
                # INFO: toolsVersion is unused because the tools package is deprecated
                # toolsVersion = "26.1.1";
                platformToolsVersion = "35.0.2";
                buildToolsVersions = [
                  "34.0.0"
                  "35.0.0"
                ];
                includeEmulator = true;
                emulatorVersion = "35.1.4";
                platformVersions = [
                  "33"
                ];
                includeSources = false;
                includeSystemImages = true;
                systemImageTypes = [ "google_apis_playstore" ];
                abiVersions = [
                  "x86_64"
                  # "armeabi-v7a"
                  # "arm64-v8a"
                ];
                cmakeVersions = [ "3.6.4111459" ];
                includeNDK = true;
                ndkVersions = [ "27.0.12077973" ];
                useGoogleAPIs = true;
                useGoogleTVAddOns = false;
                includeExtras = [
                  "extras;google;gcm"
                ];
              };
            in
            androidComposition.androidsdk;

          runtimeDeps = with pkgs; [
            # Dependencies needed for running (linked libraries like openssl)
          ];
          buildDeps = with pkgs; [
            # Libraries and programs required to compile the program
            # Included in devshell
            androidSdk
            atkmm
            # at-spi2-atk
            clang
            gdk-pixbuf
            glib
            gtk3
            lld
            lldb
            openjdk
            pkg-config
            # rustup
            rustPlatform.bindgenHook
            stdenv.cc.cc.lib
            # (wasm-bindgen-cli.overrideAttrs (oldAttrs: rec {
            #   pname = "wasm-bindgen-cli";
            #   version = "0.2.99";
            #   hash = "sha256-1AN2E9t/lZhbXdVznhTcniy+7ZzlaEp/gwLEAucs6EA=";
            #   # hash = lib.fakeHash;
            #   cargoHash = "sha256-Nfu/TwOM28I3MbS9udewK4thCsCWjQns4XZu8qxVSX8=";
            #   # cargoHash = lib.fakeHash;
            #   src = fetchCrate { inherit pname version hash; };
            #   cargoDeps = oldAttrs.cargoDeps.overrideAttrs (
            #     lib.const {
            #       name = "${pname}-vendor.tar.gz";
            #       inherit src;
            #       outputHash = cargoHash;
            #     }
            #   );
            # }))
            sqlite
            webkitgtk_4_1
            xdotool
          ];
          devDeps =
            with pkgs;
            [
              # Libraries and programs needed for dev work; included in dev shell
              # NOT included in the nix build operation
              bashInteractive
              bunyan-rs
              cargo-binstall
              cargo-deny
              cargo-edit
              cargo-expand
              cargo-msrv
              cargo-nextest
              cargo-watch
              (cargo-whatfeatures.overrideAttrs (oldAttrs: rec {
                pname = "cargo-whatfeatures";
                version = "0.9.13";
                src = fetchFromGitHub {
                  owner = "museun";
                  repo = "cargo-whatfeatures";
                  rev = "v0.9.13";
                  sha256 = "sha256-YJ08oBTn9OwovnTOuuc1OuVsQp+/TPO3vcY4ybJ26Ms=";
                };
                cargoDeps = oldAttrs.cargoDeps.overrideAttrs (
                  lib.const {
                    name = "${pname}-vendor.tar.gz";
                    inherit src;
                    outputHash = "sha256-8pccXL+Ud3ufYcl2snoSxIfGM1tUR53GUrIp397Rh3o=";
                  }
                );
                cargoBuildFlags = [
                  "--no-default-features"
                  "--features=rustls"
                ];
              }))
              dioxus-cli
              # (dioxus-cli.overrideAttrs (oldAttrs: rec {
              #   pname = "dioxus-cli";
              #   version = "0.6.1";
              #   hash = "sha256-mQnSduf8SHYyUs6gHfI+JAvpRxYQA1DiMlvNofImElU=";
              #   cargoHash = "sha256-7jNOdlX9P9yxIfHTY32IXnT6XV5/9WDEjxhvHvT7bms=";
              #   src = fetchCrate {
              #     inherit pname version;
              #     hash = hash;
              #   };
              #   cargoDeps = oldAttrs.cargoDeps.overrideAttrs (
              #     lib.const {
              #       name = "${pname}-vendor.tar.gz";
              #       inherit src;
              #       outputHash = cargoHash;
              #     }
              #   );
              #   checkFlags = [
              #     # requires network access
              #     "--skip=serve::proxy::test"
              #     "--skip=wasm_bindgen::test::test_github_install"
              #     "--skip=wasm_bindgen::test::test_cargo_install"
              #   ];
              # }))
              flyctl
              gdb
              just
              nushell
              panamax
              zellij
            ]
            ++ [
              inputs.surrealdb-gh.packages.${system}.default
            ];

          cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
          msrv = cargoToml.package.rust-version;

          rustPackage =
            features:
            (pkgs.makeRustPlatform {
              cargo = pkgs.rust-bin.stable.latest.minimal;
              rustc = pkgs.rust-bin.stable.latest.minimal;
            }).buildRustPackage
              {
                inherit (cargoToml.package) name version;
                src = ./.;
                cargoLock.lockFile = ./Cargo.lock;
                buildFeatures = features;
                buildInputs = runtimeDeps;
                nativeBuildInputs = buildDeps;
                # Uncomment if your cargo tests require networking or otherwise
                # don't play nicely with the nix build sandbox:
                # doCheck = false;
              };

          mkDevShell =
            rustc:
            pkgs.mkShell {
              shellHook = ''
                # TODO: figure out if it's possible to remove this or allow a user's preferred shell
                exec env SHELL=${pkgs.bashInteractive}/bin/bash zellij --layout ./zellij_layout.kdl
              '';
              # LD_LIBRARY_PATH =
              #   with pkgs;
              #   lib.makeLibraryPath [
              #     stdenv.cc.cc.lib
              #   ];
              ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
              ANDROID_NDK_HOME = "${androidSdk}/libexec/android-sdk/ndk-bundle";
              RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
              buildInputs = runtimeDeps;
              nativeBuildInputs = buildDeps ++ devDeps ++ [ rustc ];
            };

          rustTargets = [
            "x86_64-unknown-linux-gnu"
            "x86_64-linux-android"
            "aarch64-linux-android"
            "wasm32-unknown-unknown"
          ];
          rustExtensions = [
            "rust-analyzer"
            "rust-src"
          ];
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ (import inputs.rust-overlay) ];
            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "android-sdk-tools"
                  "android-sdk-cmdline-tools"
                  "surrealdb"
                ];
              android_sdk.accept_license = true;
            };
          };

          packages.default = self'.packages.base;
          devShells.default = self'.devShells.nightly;

          packages.base = (rustPackage "");
          packages.bunyan = (rustPackage "bunyan");
          packages.tokio-console = (rustPackage "tokio-console");

          devShells.nightly = (
            mkDevShell (
              pkgs.rust-bin.selectLatestNightlyWith (
                toolchain:
                toolchain.default.override {
                  extensions = rustExtensions;
                  targets = rustTargets;
                }
              )
            )
          );
          devShells.stable = (
            mkDevShell (
              pkgs.rust-bin.stable.latest.default.override {
                extensions = rustExtensions;
                targets = rustTargets;
              }
            )
          );
          devShells.msrv = (
            mkDevShell (
              pkgs.rust-bin.stable.${msrv}.default.override {
                extensions = rustExtensions;
                targets = rustTargets;
              }
            )
          );
        };
    };
}
