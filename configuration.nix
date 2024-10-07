{ config
, ...
}:
let
  pkgs = import ./dep/nixpkgs {};
  polygon = import ./default.nix {
    inherit pkgs;
    network = cfg.network;
  };
  cfg = config.services.polygon;
  serviceDir = "/var/lib/polygon/${cfg.network}";
in
with pkgs.lib;
{
  options.services.polygon = {
    enable = mkEnableOption "Polygon Node Services";
    # Currently only mumbai is supported
    network = mkOption {
      type = types.str;
      default = "mumbai";
    };
    ip = mkOption {
      type = types.str;
      default = "127.0.0.1";
    };
    # These defaults match the original bor config files
    geth.ports = {
      http = mkOption {
        type = types.int;
        default = 9545;
      };
      listen = mkOption {
        type = types.int;
        default = 30300;
      };
    };
    bor = {
      gcmode = mkOption {
        type = types.str;
        default = "full";
      };
      ports = {
        http = mkOption {
          type = types.int;
          default = 8545;
        };
        listen = mkOption {
          type = types.int;
          default = 30303;
        };
        prof = mkOption {
          type = types.int;
          default = 7071;
        };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services = assert (cfg.network == "mumbai"); {
      "polygon-${cfg.network}-geth" = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Polygon ${cfg.network} Ethereum Node";
        preStart = ''
          mkdir -p ${serviceDir}/geth
        '';
        serviceConfig = {
          Type = "simple";
          ProtectHome = "yes";
          ProtectSystem = "full";
          Restart = "always";
          RestartSec = 30;
          # I'm not sure which of these address options is actually used, the
          # addresses are also specified in the config files.
          ExecStart = ''
            ${pkgs.go-ethereum}/bin/geth \
              --goerli --syncmode full \
              --port ${toString cfg.geth.ports.listen} \
              --http --http.port ${toString cfg.geth.ports.http} \
              --datadir ${serviceDir}/geth
          '';
        };
      };
      "polygon-${cfg.network}-bor" = {
        wantedBy = [ "multi-user.target" ];
        description = "Polygon ${cfg.network} Bor Node";
        # TODO This will regenerate keys and it probably shouldn't
        preStart = ''
          mkdir -p ${serviceDir}/bor

          NETWORK=${polygon.launch-src}/testnet-v4
          LAUNCH_NODE_DIR=$NETWORK/sentry/sentry

          # From launch/node/bor/setup.sh does for testnet/sentry nodes
          mkdir -p ${serviceDir}/bor/keystore
          ${polygon.bor}/bin/bor --datadir ${serviceDir}/bor/data init $LAUNCH_NODE_DIR/bor/genesis.json
          ${polygon.bor}/bin/bootnode -genkey ${serviceDir}/bor/data/nodekey
          # Write static-nodes.json
          ENODE=$(${polygon.bor}/bin/bootnode -nodekey ${serviceDir}/bor/data/nodekey -writeaddress)
          echo "[\"enode://$ENODE@${cfg.ip}:${toString cfg.bor.ports.listen}\"]" > ${serviceDir}/bor/data/bor/static-nodes.json
        '';
        serviceConfig = {
          Type = "simple";
          ProtectHome = "yes";
          ProtectSystem = "full";
          Restart = "always";
          RestartSec = 30;
          ExecStart = ''
            ${polygon.bor}/bin/bor \
              --datadir ${serviceDir}/bor/data \
              --port ${toString cfg.bor.ports.listen} \
              --http --http.addr '0.0.0.0' \
              --http.vhosts '*' \
              --http.corsdomain '*' \
              --http.port ${toString cfg.bor.ports.http} \
              --ipcpath ${serviceDir}/bor/data/bor.ipc \
              --http.api 'eth,net,web3,txpool,bor' \
              --syncmode 'full' \
              --gcmode '${cfg.bor.gcmode}' \
              --networkid '80001' \
              --miner.gaslimit '20000000' \
              --miner.gastarget '20000000' \
              --txpool.nolocals \
              --txpool.accountslots 16 \
              --txpool.globalslots 131072 \
              --txpool.accountqueue 64 \
              --txpool.globalqueue 131072 \
              --txpool.lifetime '1h30m0s' \
              --maxpeers 200 \
              --metrics \
              --pprof --pprof.port ${toString cfg.bor.ports.prof} --pprof.addr '0.0.0.0' \
              --bootnodes "enode://320553cda00dfc003f499a3ce9598029f364fbb3ed1222fdc20a94d97dcc4d8ba0cd0bfa996579dcc6d17a534741fb0a5da303a90579431259150de66b597251@54.147.31.250:30303,enode://f0f48a8781629f95ff02606081e6e43e4aebd503f3d07fc931fad7dd5ca1ba52bd849a6f6c3be0e375cf13c9ae04d859c4a9ae3546dc8ed4f10aa5dbb47d4998@34.226.134.117:30303"
          '';
        };
      };
    };
  };
}