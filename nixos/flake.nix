{
  description = "CuiperHive — modulaire NixOS werkplek";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, rust-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
        config.allowUnfree = true;
      };

      # ─── Basismodules — altijd geladen ──────────────────────────────────
      basisModules = [
        ./modules/CuiperPorts.nix
        ./modules/CuiperSystem.nix
        ./modules/CuiperDesktop.nix
        ./modules/CuiperServices.nix
        ./modules/CuiperDatabases.nix
        ./modules/CuiperNginx.nix
        ./modules/CuiperDev.nix
        ./modules/CuiperHyperon.nix
        ./modules/CuiperJaeger.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs       = true;
          home-manager.useUserPackages     = true;
          home-manager.users.reparateur    = import ./home/default.nix;
          home-manager.extraSpecialArgs    = { inherit rust-overlay; };
        }
      ];

      # ─── Helper: bouw een CuiperHive systeem met klantprofiel ───────────
      # Gebruik: mkCuiperSystem ./clients/acme.nix
      mkCuiperSystem = klantProfiel:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = basisModules ++ [ klantProfiel ];
        };

    in {

      # ─── Klantprofielen ─────────────────────────────────────────────────
      # nixos-rebuild switch --flake .#<naam>

      nixosConfigurations = {

        # Volledige installatie — alle services aan
        standaard = mkCuiperSystem ./clients/standaard.nix;

        # AI/ML focus — Ollama, MindsDB, MLflow, Neo4j
        ai-werkstation = mkCuiperSystem ./clients/ai-werkstation.nix;

        # Minimaal — alleen PostgreSQL + Gitea + Redis
        minimal = mkCuiperSystem ./clients/minimal.nix;

        # Achterwaartse compatibiliteit met oude naam
        reparatie-usb = mkCuiperSystem ./clients/standaard.nix;
      };
    };
}
