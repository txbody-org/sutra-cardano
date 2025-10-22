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

      in with pkgs; {
        modules = [
          nix-ld.nixosModules.nix-ld

          { programs.nix-ld.dev.enable = true; }
        ];


        devShell = pkgs.mkShell {
          buildInputs = [
            beamMinimal28Packages.elixir_1_19
            beamMinimal28Packages.elixir-ls
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

        shellHook = ''
            echo "Elixir version:"
            elixir --version
        '';
      });
}

