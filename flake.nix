{
  description = "PJalv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode-flake = {
      url = "github:PJalv/opencode-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos-anywhere: disko for declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri: scrollable-tiling Wayland compositor
    niri = {
      url = "github:sodiboo/niri-flake";
    };

    # navegante dev shell dependencies
    nixpkgs-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nur,
    firefox-addons,
    spicetify-nix,
    nixos-wsl,
    opencode-flake,
    disko,
    niri,
    nixpkgs-ruby,
    flake-utils,
  } @ inputs: let
    # Shared dotfiles repository
    dotfilesRepo = nixpkgs.legacyPackages.x86_64-linux.fetchgit {
      url = "https://github.com/PJalv/dotfiles.git";
      rev = "26cf90d1e388e03578bc63f951d6a5e4a1c6d660";
      sha256 = "sha256-mKiG0RJNh72+ppyz7q/5TiC1APVPjvgnhv/yLqXH30I=";
    };
    dotfilesDir = dotfilesRepo;

    # Navegante dev shell configuration
    naveganteDevShell = system: let
      pkgs = import nixpkgs { inherit system; };
      ruby = nixpkgs-ruby.packages.${system}."ruby-3.4.7";

      # Playwright packages (from nixpkgs top-level)
      # pkgs.playwright-driver = playwright-core (the core library)
      # pkgs.playwright-test  = playwright test runner
      # pkgs.playwright-driver.passthru.browsers = bundled browser binaries

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

        if [ ! -f "$PGDATA/PG_VERSION" ]; then
          echo "Initializing PostgreSQL database cluster..."
          ${pkgs.postgresql_17}/bin/initdb -D "$PGDATA" --username=${dbUser} --auth=trust
          echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"
          echo "host all all ::1/128 trust" >> "$PGDATA/pg_hba.conf"
          echo "PostgreSQL initialized."
        fi

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

        ${servicesStop}/bin/services-stop 2>/dev/null || true

        if [ -d "${stateDir}/postgres" ]; then
          echo "Removing PostgreSQL data directory..."
          rm -rf "${stateDir}/postgres"
        fi

        if [ -d "${stateDir}/redis" ]; then
          echo "Removing Redis data directory..."
          rm -rf "${stateDir}/redis"
        fi

        if [ -d ".gems" ]; then
          echo "Removing .gems directory..."
          rm -rf ".gems"
        fi

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

    in pkgs.mkShell {
      buildInputs = [
        # Ruby
        ruby

        # Node.js
        pkgs.nodejs

        # Dev tools
        pkgs.git
        pkgs.stripe-cli

        # Native gem dependencies
        pkgs.libyaml
        pkgs.postgresql_17
        pkgs.openssl
        pkgs.zlib
        pkgs.libxml2
        pkgs.libxslt

        # Services
        pkgs.redis

        # Playwright & Playwright MCP
        pkgs.playwright-test
        pkgs.playwright-driver

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
        pkgs.pkg-config
      ];

      shellHook = ''
        echo "Navegante Web -nix flake-"
        echo ""

        # Set up environment for native gem compilation
        export PGDATA="$PWD/${stateDir}/postgres"
        export REDIS_DATA="$PWD/${stateDir}/redis"

        # Configure gems to use project-local directory
        export GEM_HOME="$PWD/.gem"
        export GEM_PATH="$GEM_HOME"
        export BUNDLE_PATH="$GEM_HOME"
        export BUNDLE_BIN="$GEM_HOME/bin"
        export PATH="$GEM_HOME/bin:$PATH"

        # Playwright environment
        export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.passthru.browsers}"
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

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
        echo "Playwright: $(playwright --version 2>/dev/null || echo 'available via playwright-test')"
        echo "Playwright MCP: install via 'npm install -g @anthropic-ai/mcp-server-playwright'"
        echo ""
      '';
    };
  in {
    nixosConfigurations = {
      # ── Existing configurations (unchanged) ──────────────────────────
      smighty = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          machine = "desktop";
          username = "pjalv";
          inherit dotfilesDir inputs;
        };
        modules = [
          ./modules/dotfiles.nix
          ./modules/optimization.nix
          ./users/pjalv/user.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.useGlobalPkgs = true;
            home-manager.users.pjalv = import ./users/pjalv/hm.nix;
            home-manager.extraSpecialArgs = {
              machine = "desktop";
              username = "pjalv";
              inherit dotfilesDir inputs;
            };
          }
        ];
      };
      pjalv-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          machine = "laptop";
          username = "pjalv";
          inherit dotfilesDir inputs;
        };
        modules = [
          ./modules/dotfiles.nix
          ./modules/optimization.nix
          ./users/pjalv/user.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.pjalv = import ./users/pjalv/hm.nix;
            home-manager.extraSpecialArgs = {
              machine = "laptop";
              username = "pjalv";
              inherit dotfilesDir inputs;
            };
          }
        ];
      };
      pjalv-wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          machine = "wsl";
          username = "pjalv";
          inherit dotfilesDir inputs;
        };
        modules = [
          nixos-wsl.nixosModules.default
          {
            system.stateVersion = "24.05";
            wsl.enable = true;
            wsl.defaultUser = "pjalv";
          }
          ./users/pjalv/wsl.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.pjalv = import ./users/remote/hm.nix;
            home-manager.extraSpecialArgs = {
              machine = "wsl";
              username = "pjalv";
              inherit dotfilesDir inputs;
            };
          }
        ];
      };

      # ── New: nixos-anywhere deployable config with niri ──────────────
      nix-laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          disko.nixosModules.disko
          niri.nixosModules.niri
          ./nix-laptop-configuration.nix
          ./hardware-configuration.nix
        ];
      };
    };

    homeConfigurations = let
      username = "ubuntu";
      pkgs = import nixpkgs {system = "x86_64-linux";};
      # pkgs = import nixpkgs {system = "aarch64-linux";}; # For ARM-based systems
    in {
      "${username}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [./users/remote/hm.nix];
        extraSpecialArgs = {
          inherit username dotfilesDir inputs;
        };

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };

    # ── Navegante dev shell (integrated from navegante-flake.nix) ────
    devShells = builtins.listToAttrs (map (system: {
      name = system;
      value = {
        default = naveganteDevShell system;
      };
    }) [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]);
  };
}
