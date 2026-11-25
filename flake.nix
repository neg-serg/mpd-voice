{
  description = "mpd-voice — voice control for MPD over local speech recognition";

  # Minimal on purpose: the host flake consumes `packages.<system>.default` and
  # makes this input follow its nixpkgs pin, so the binary is built against the
  # same nixpkgs as the system that runs it.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        mpd-voice = self.packages.${system}.default;
      });

      # The audio-free paths need no microphone, no MPD and no speech backend:
      # the phrase table, the intent parser and a dry run of the typed pipeline
      # are what CI (and `nix flake check`) can verify on any machine.
      checks = forAllSystems (system: {
        cli =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            pkg = self.packages.${system}.default;
          in
          pkgs.runCommand "mpd-voice-cli" { } ''
            ${pkg}/bin/mpd-voice phrases > /dev/null
            ${pkg}/bin/mpd-voice parse 'next track' > /dev/null
            ${pkg}/bin/mpd-voice say --dry-run 'volume 40' > /dev/null
            touch "$out"
          '';
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            cargo
            rustc
            clippy
            rustfmt
            rust-analyzer
          ];
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
