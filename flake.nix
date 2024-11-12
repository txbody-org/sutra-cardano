{
  description = "Elixir flake";
  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
  };

outputs = { self, nixpkgs, flake-utils }:
 flake-utils.lib.eachDefaultSystem (system:
    let
      inherit (pkgs.lib) optional optionals;
      pkgs = import nixpkgs { inherit system; };

      #elixir = pkgs.beam.packages.erlang_27.elixir.override {
      #  version = "1.17.2";
      #  rev = "47abe2d107e654ccede845356773bcf6e11ef7cb";
      #  sha256 = "sha256-8rb2f4CvJzio3QgoxvCv1iz8HooXze0tWUJ4Sc13dxg=";
      #};

    in
    with pkgs;
    {
      devShell = pkgs.mkShell {
        buildInputs = [
          elixir_1_16
          elixir_ls
          glibcLocales
	 
        ] ++ optional stdenv.isLinux inotify-tools
          ++ optional stdenv.isDarwin terminal-notifier
          ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
            CoreFoundation
            CoreServices
          ]);
      };
    });
}