{
  description = "Reparatie USB - NixOS werkplek";

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
    in {
      # Systeem configuratie (NixOS)
      nixosConfigurations.reparatie-usb = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules/ports.nix
          ./modules/system.nix
          ./modules/desktop.nix
          ./modules/services.nix
          ./modules/databases.nix
          ./modules/dev.nix
          ./modules/nginx.nix

          # Home Manager als module zodat het mee rebuildt
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.reparateur = import ./home/default.nix;
            home-manager.extraSpecialArgs = { inherit rust-overlay; };
          }
        ];
      };
    };
}
