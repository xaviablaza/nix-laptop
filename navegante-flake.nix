{
  description = "Navegante development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-ruby,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        ruby = nixpkgs-ruby.packages.${system}."ruby-3.4.7";

        # Configuration
        dbName = "navegante_development";
        dbUser = "postgres";
        dbPort = 5432;
        redisPort = 6379;
        stateDir = ".nix-state";

        # PostgreSQL scripts
        pgStart = pkgs.writeShellScriptBin "pg-start" ''
          set -e
          PGDATA="$PWD/${stateDir}/postgres"
          mkdir -p "$PGDATA"

          # Initialize if needed
          if [ ! -f "$PGDATA/PG_VERSION" ]; then
            echo "Initializing PostgreSQL database cluster..."
            ${pkgs.postgresql_17}/bin/initdb -D "$PGDATA" --username=${dbUser} --auth=trust
            echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"
            echo "host all all ::1/128 trust" >> "$PGDATA/pg_hba.conf"
            echo "PostgreSQL initialized."
          fi

          # Check if already running
          if ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" status > /dev/null 2>&1; then
            echo "PostgreSQL is already running."
            exit 0
          fi

          echo "Starting PostgreSQL..."
          ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" -l "$PGDATA/postgres.log" -o "-p ${toString dbPort} -k $PGDATA" start
          echo "PostgreSQL started on port ${toString dbPort}."
        '';

        pgStop = pkgs.writeShellScriptBin "pg-stop" ''
          PGDATA="$PWD/${stateDir}/postgres"
          if [ ! -d "$PGDATA" ]; then
            echo "PostgreSQL data directory not found."
            exit 0
          fi
          if ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" status > /dev/null 2>&1; then
            echo "Stopping PostgreSQL..."
            ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" stop -m fast
            echo "PostgreSQL stopped."
          else
            echo "PostgreSQL is not running."
          fi
        '';

        pgStatus = pkgs.writeShellScriptBin "pg-status" ''
          PGDATA="$PWD/${stateDir}/postgres"
          if [ ! -d "$PGDATA" ]; then
            echo "PostgreSQL data directory not found."
            exit 1
          fi
          ${pkgs.postgresql_17}/bin/pg_ctl -D "$PGDATA" status
        '';

        # Redis scripts
        redisStart = pkgs.writeShellScriptBin "redis-start" ''
          set -e
          REDIS_DATA="$PWD/${stateDir}/redis"
          mkdir -p "$REDIS_DATA"

          PIDFILE="$REDIS_DATA/redis.pid"

          # Check if already running
          if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "Redis is already running (pid $(cat "$PIDFILE"))."
            exit 0
          fi

          echo "Starting Redis..."
          ${pkgs.redis}/bin/redis-server \
            --port ${toString redisPort} \
            --dir "$REDIS_DATA" \
            --daemonize yes \
            --pidfile "$PIDFILE" \
            --logfile "$REDIS_DATA/redis.log"
          echo "Redis started on port ${toString redisPort}."
        '';

        redisStop = pkgs.writeShellScriptBin "redis-stop" ''
          REDIS_DATA="$PWD/${stateDir}/redis"
          PIDFILE="$REDIS_DATA/redis.pid"

          if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "Stopping Redis..."
            ${pkgs.redis}/bin/redis-cli -p ${toString redisPort} shutdown nosave 2>/dev/null || kill "$(cat "$PIDFILE")"
            rm -f "$PIDFILE"
            echo "Redis stopped."
          else
            echo "Redis is not running."
            rm -f "$PIDFILE"
          fi
        '';

        redisStatus = pkgs.writeShellScriptBin "redis-status" ''
          REDIS_DATA="$PWD/${stateDir}/redis"
          PIDFILE="$REDIS_DATA/redis.pid"

          if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "Redis is running (pid $(cat "$PIDFILE"))."
            ${pkgs.redis}/bin/redis-cli -p ${toString redisPort} ping
          else
            echo "Redis is not running."
            exit 1
          fi
        '';

        # Combined scripts
        servicesStart = pkgs.writeShellScriptBin "services-start" ''
          ${pgStart}/bin/pg-start
          ${redisStart}/bin/redis-start
        '';

        servicesStop = pkgs.writeShellScriptBin "services-stop" ''
          ${pgStop}/bin/pg-stop
          ${redisStop}/bin/redis-stop
        '';

        servicesStatus = pkgs.writeShellScriptBin "services-status" ''
          echo "=== PostgreSQL ==="
          ${pgStatus}/bin/pg-status || true
          echo ""
          echo "=== Redis ==="
          ${redisStatus}/bin/redis-status || true
        '';

        # Database initialization
        initDatabase = pkgs.writeShellScriptBin "init-database" ''
          set -e
          echo "Checking if database ${dbName} exists..."
          if ! ${pkgs.postgresql_17}/bin/psql -h localhost -p ${toString dbPort} -U ${dbUser} -lqt | cut -d \| -f 1 | grep -qw ${dbName}; then
            echo "Creating database ${dbName}..."
            ${pkgs.postgresql_17}/bin/createdb -h localhost -p ${toString dbPort} -U ${dbUser} ${dbName}
            echo "Database ${dbName} created."
          else
            echo "Database ${dbName} already exists."
          fi
        '';

        # Clean rebuild script
        cleanRebuild = pkgs.writeShellScriptBin "clean-rebuild" ''
          set -e
          echo "Cleaning stateful caches..."
          echo ""

          # Stop services if running
          ${servicesStop}/bin/services-stop 2>/dev/null || true

          # Clean PostgreSQL state
          if [ -d "${stateDir}/postgres" ]; then
            echo "Removing PostgreSQL data directory..."
            rm -rf "${stateDir}/postgres"
          fi

          # Clean Redis state
          if [ -d "${stateDir}/redis" ]; then
            echo "Removing Redis data directory..."
            rm -rf "${stateDir}/redis"
          fi

          # Clean Ruby gems
          if [ -d ".gems" ]; then
            echo "Removing .gems directory..."
            rm -rf ".gems"
          fi

          # Clean node modules
          if [ -d "node_modules" ]; then
            echo "Removing node_modules..."
            rm -rf node_modules
          fi

          echo ""
          echo "Reinstalling dependencies..."
          bundle install
          npm install

          echo ""
          echo "Done! Run 'services-start' to start PostgreSQL and Redis."
          echo "Then run 'bin/rails db:create db:migrate db:seed' to set up the database."
        '';

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            # Ruby
            ruby

            # Node.js
            pkgs.nodejs

            # Dev tools
            pkgs.git
            pkgs.stripe-cli

            # Native gem dependencies
            pkgs.libyaml # psych gem
            pkgs.postgresql_17 # pg gem (includes libpq)
            pkgs.openssl # bcrypt, puma, net-ssh, etc.
            pkgs.zlib # general compression
            pkgs.libxml2 # nokogiri (if compiling from source)
            pkgs.libxslt # nokogiri

            # Services
            pkgs.redis

            # Helper scripts
            pgStart
            pgStop
            pgStatus
            redisStart
            redisStop
            redisStatus
            servicesStart
            servicesStop
            servicesStatus
            initDatabase
            cleanRebuild
          ];

          nativeBuildInputs = [
            pkgs.pkg-config # helps gems find native libraries
          ];

          shellHook = ''
            echo "Navegante Web -nix flake-"
            echo ""

            # Set up environment for native gem compilation
            export PGDATA="$PWD/${stateDir}/postgres"
            export REDIS_DATA="$PWD/${stateDir}/redis"

            # Configure gems to use project-local directory
            # GEM_HOME/GEM_PATH ensure 'gem install' uses local dir
            # BUNDLE_PATH/BUNDLE_BIN ensure 'bundle install' uses same location
            export GEM_HOME="$PWD/.gem"
            export GEM_PATH="$GEM_HOME"
            export BUNDLE_PATH="$GEM_HOME"
            export BUNDLE_BIN="$GEM_HOME/bin"
            export PATH="$GEM_HOME/bin:$PATH"

            # Ensure state directory exists
            mkdir -p "${stateDir}"

            echo "Available commands:"
            echo "  services-start  - Start PostgreSQL and Redis"
            echo "  services-stop   - Stop PostgreSQL and Redis"
            echo "  services-status - Check service status"
            echo "  pg-start/stop/status   - PostgreSQL controls"
            echo "  redis-start/stop/status - Redis controls"
            echo "  init-database   - Create development database"
            echo "  clean-rebuild   - Clean all state and reinstall deps"
            echo ""
          '';
        };
      }
    );
}
