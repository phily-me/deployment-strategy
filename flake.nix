{
  description = "Development environment for Python FastAPI deployment project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Python and package management
            python311
            uv

            # Build and task runner
            just

            # Container tools
            docker
            docker-compose

            # Network and deployment tools
            curl
            openssh
            netcat-gnu

            # JSON processing
            jq

            # System utilities
            envsubst
            nettools

            # Development tools
            git
            gnumake
          ];

          shellHook = ''
            echo "🚀 Development environment ready!"
            echo "Available tools:"
            echo "  • uv (Python package manager)"
            echo "  • just (command runner)"
            echo "  • docker & docker-compose (containers)"
            echo "  • curl, ssh, jq (deployment tools)"
            echo ""
            echo "Run 'just' to see available commands"
          '';
        };
      });
}