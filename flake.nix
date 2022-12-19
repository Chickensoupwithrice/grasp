{
  description = "Reproducible Environment for Grasp server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    grasp.url = "github:karlicoss/grasp";
    grasp.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, grasp }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          packages.grasp = pkgs.stdenv.mkDerivation rec {
            pname = "grasp";
            version = "v0.6.6";
            src = grasp;

            installPhase = ''
              mkdir -p  $out/bin
              cp -r server/* $out/bin/
            '';
          };
          devShell = pkgs.mkShell {
            buildInputs = [ pkgs.python3 ];
          };
        }) // {
      nixosModule = { options, lib, config, pkgs, ... }:
        let
          graspConfig = config.services."grasp";

          options = {
            enable = lib.mkEnableOption "Grasp service";
            path = lib.mkOption rec {
              type = lib.types.path;
              default = "/var/lib/grasp/";
              example = "/var/lib/grasp";
              description = "Where to run Grasp from";
            };
            #port = lib.mkOption rec {
            #  type = lib.types.int;
            #  default = 12212;
            #  example = 12212;
            #  description = "Port to run the server on";
            #};
            user = lib.mkOption rec {
              type = lib.types.str;
              default = "";
              example = "nixos";
              description = "User to run the service as";
            };
            #template = mkOption rec {
            #  type = types.str;
            #  default = "12212";
            #  example = "12212";
            #  description = "Template to use";
            #};
          };
        in
        {
          options.services.grasp-server = options;
          config = lib.mkIf graspConfig.enable {
            systemd.services.grasp-server = {
              description = ''
                A grasp server module
              '';
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                #DynamicUser = true; # Probably should default to this if no user supplied
                User = "${graspConfig.user}";
                RuntimeDirectory = "${graspConfig.path}";
                RuntimeDirectoryMode = "0755";
                StateDirectory = "${graspConfig.path}";
                StateDirectoryMode = "0700";
              };
              path = with pkgs; [ nix python3 ] ++ [ ];
              script = ''
                ${self.packages.${pkgs.system}.grasp}/bin/grasp_server.py --path ${graspConfig.path} 
              '';
            };
            # Allow nginx through the firewall
            networking.firewall.allowedTCPPorts = [ 12212 ];
          };
        };
      # Test container
      nixosConfigurations."test" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModule
          ({ pkgs, ... }: {
            # Only allow this to boot as a container
            boot.isContainer = true;
            networking.hostName = "grasp";
            services."grasp".enable = true;
            services."grasp".user = "anish";
            services."grasp".path = "/home/anish/grasp/capture.org";
            # I think I actually created the above folder as well in the container
            # I figured dynamic user with their own text file seems less useful
            # I didn't know how to default to a 
            users.users.anish = {
              isNormalUser = true;
              password = "password";
            };
          })
        ];
      };
    };
}


