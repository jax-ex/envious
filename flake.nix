{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ nixpkgs, utils, ... }:
    let
      supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux"];
    in
      utils.lib.eachSystem supportedSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          packages = pkgs.beam.packages.erlang_25.extend (final: prev: {
            # Our project requires elixir-1.16
            elixir = final.elixir_1_16;
          });
          inherit (packages) elixir;
        in {
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs;
              [elixir mix2nix] ++
              lib.optionals stdenv.isLinux [ inotify-tools ] ++
              lib.optionals stdenv.isDarwin
                (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ]);

            shellHook = ''
              # this allows mix to work on the local directory
              mkdir -p .nix-mix .nix-hex
              export MIX_HOME=$PWD/.nix-mix
              export HEX_HOME=$PWD/.nix-mix

              # make hex from Nixpkgs available
              # `mix local.hex` will install hex into MIX_HOME and should take precedence
              export MIX_PATH="${pkgs.beam.packages.erlang.hex}/lib/erlang/lib/hex/ebin"
              export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
              export LANG=C.UTF-8
              # keep your shell history in iex
              export ERL_AFLAGS="-kernel shell_history enabled"
            '';
          };

          packages.default =
            let
              mixNixDeps = with pkgs; import ./mix_deps.nix { inherit lib beamPackages; };
            in
              packages.buildMix {
                name = "envious";
                version = "0.0.1";
                src = ./.;

                # All packages in mix_deps.nix
                beamDeps = pkgs.lib.attrValues mixNixDeps;

                # Run tests after build
                postBuild = ''
                  mix test --no-deps-check
                '';
              };
        });
}
