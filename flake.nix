{
  description = "Elixir flake";
  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
    nix-ld = { url = "github:Mic92/nix-ld"; };

  };

  outputs = { self, nixpkgs, flake-utils, nix-ld }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (pkgs.lib) optional optionals;
        pkgs = import nixpkgs { inherit system; };

        elixir = pkgs.beam.packages.erlang_27.elixir.override {
          version = "1.18";
          rev = "v1.18-latest";
          sha256 = "sha256-N+6hpeo5M4L/mLRVXSP2P0w0fkx6iy0HAmEEGYYI7jY=";
        };

      in with pkgs; {
        modules = [
          nix-ld.nixosModules.nix-ld

          { programs.nix-ld.dev.enable = true; }
        ];

        shellHook = ''
          export SHELL=/usr/bin/bash
        '';

        devShell = pkgs.mkShell {
          buildInputs = [
            elixir
            elixir_ls
            glibcLocales
            cargo
            rustc
            libtool
            autoconf
            automake
            libsodium
          ] ++ optional stdenv.isLinux inotify-tools
            ++ optional stdenv.isDarwin terminal-notifier
            ++ optionals stdenv.isDarwin
            (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ]);
        };
      });
}

