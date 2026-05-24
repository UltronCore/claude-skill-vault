---
name: nix-reproducible-builds
description: Use Nix and NixOS for fully reproducible development environments, CI pipelines, and deployments. Covers flake-based project setup, devShells, Nix overlays, home-manager, NixOS configuration, and building Docker images with Nix for bit-reproducible containers.
version: 1.0.0
tags: [nix, nixos, flakes, devshell, reproducible-builds, home-manager, nix-overlays, docker-nix, ci-cd]
---

# Nix Reproducible Builds

## Overview

Nix is a purely functional package manager where every package is built in isolation, pinned by cryptographic hash, and stored immutably — making builds reproducible across any Linux or macOS machine, any CI runner, and any point in time. Nix Flakes formalize this with locked dependency graphs (`flake.lock`), replacing shell scripts and Docker snapshots as the reproducibility mechanism. The result: "works on my machine" becomes a guarantee, not a hope.

## When to Use

- Teams where "it works on my machine" is a recurring problem across dev/CI/production
- Projects needing exact binary reproducibility for compliance or security audit trails
- Multi-language monorepos where each language needs different toolchain versions simultaneously
- CI pipelines that must be fast, cache-efficient, and deterministic
- Replacing Dockerfile-based environments with something that's both hermetic and composable
- NixOS servers that need declarative, rollback-capable system configuration
- Building minimal Docker images without the overhead of layered Dockerfiles

## Step-by-Step Workflow

### 1. Install Nix and Enable Flakes

```bash
# Install Nix (multi-user, recommended)
sh <(curl -L https://nixos.org/nix/install) --daemon

# macOS: use the Determinate Systems installer (handles SIP correctly)
curl --proto '=https' --tlsv1.2 -sSf https://install.determinate.systems/nix | sh -s -- install

# Enable Flakes (add to ~/.config/nix/nix.conf or /etc/nix/nix.conf)
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf

# Verify
nix --version
nix flake --help
```

### 2. Basic flake.nix — Project Dev Shell

```nix
# flake.nix — pin all tools for your project
{
  description = "My project development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        # Development shell: `nix develop` or `direnv allow`
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Language runtimes — pinned versions
            nodejs_22
            python312
            go_1_22
            rustup

            # Build tools
            gnumake
            cmake

            # CLI utilities
            jq
            curl
            git
            gh

            # Database tools
            postgresql_16
            redis
          ];

          # Environment variables set in the shell
          shellHook = ''
            echo "Dev environment loaded!"
            echo "Node: $(node --version)"
            echo "Python: $(python --version)"
            export DATABASE_URL="postgresql://localhost:5432/mydb"
            export REDIS_URL="redis://localhost:6379"
          '';
        };

        # Expose packages defined in this flake
        packages.default = pkgs.stdenv.mkDerivation {
          name = "my-app";
          src = ./.;
          buildInputs = with pkgs; [ nodejs_22 ];
          buildPhase = "npm ci && npm run build";
          installPhase = "cp -r dist $out";
        };
      }
    );
}
```

```bash
# Use the dev shell
nix develop                          # Enter the shell
nix develop --command node index.js # Run a command without entering shell

# Pin dependencies (creates flake.lock)
nix flake update    # Update all inputs to latest
nix flake lock      # Update flake.lock without changing inputs

# Show what's available
nix flake show
nix flake metadata  # Show dependency graph with hashes

# Add direnv for auto-activation (.envrc)
echo "use flake" > .envrc
direnv allow        # Now shell activates automatically on cd
```

### 3. Multi-Language Project with Overlays

```nix
# flake.nix — override specific package versions with overlays
{
  description = "Project with custom package versions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable }:
    let
      system = "x86_64-linux";

      # Overlay: cherry-pick packages from unstable into stable
      overlay = final: prev: {
        # Use unstable's Node.js
        nodejs = nixpkgs-unstable.legacyPackages.${system}.nodejs_22;
        # Custom package: install a specific npm package globally
        my-cli = prev.nodePackages.buildNodeApplication {
          name = "my-cli";
          src = ./cli;
          version = "1.0.0";
        };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs       # Now uses unstable's version via overlay
          python312
          poetry
          my-cli
        ];
      };

      # Multiple shells for different purposes
      devShells.${system}.backend = pkgs.mkShell {
        packages = with pkgs; [ go_1_22 golangci-lint protobuf grpc ];
      };

      devShells.${system}.frontend = pkgs.mkShell {
        packages = with pkgs; [ nodejs_22 yarn chromium playwright-driver.browsers ];
        shellHook = ''
          export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
        '';
      };
    };
}
```

### 4. Building Docker Images with Nix

```nix
# Build a minimal, reproducible Docker image — no Dockerfile needed
# The resulting image has no shell, no package manager, only what's declared
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Build: nix build .#dockerImage
      # Load: docker load < result
      packages.${system}.dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "my-app";
        tag = "latest";

        # Contents: only what you declare
        contents = with pkgs; [
          # The app binary
          (pkgs.buildGoModule {
            pname = "my-server";
            version = "1.0.0";
            src = ./server;
            vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          })
          # Minimal runtime deps
          cacert  # TLS certificates
          tzdata  # Timezone data
        ];

        config = {
          Cmd = [ "/bin/my-server" ];
          ExposedPorts = { "8080/tcp" = {}; };
          Env = [
            "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            "TZDIR=${pkgs.tzdata}/share/zoneinfo"
          ];
          # Run as non-root
          User = "1000:1000";
        };

        # Maximize layer sharing across images
        maxLayers = 120;
      };

      # Scratch image (zero packages, just your binary)
      packages.${system}.minimalImage = pkgs.dockerTools.buildImage {
        name = "my-app-minimal";
        tag = "scratch";
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ self.packages.${system}.myBinary ];
          pathsToLink = [ "/bin" ];
        };
        config.Cmd = [ "/bin/my-server" ];
      };
    };
}
```

```bash
# Build the Docker image
nix build .#dockerImage

# Load into Docker daemon
docker load < result

# Push to registry
docker tag my-app:latest registry.example.com/my-app:$(git rev-parse --short HEAD)
docker push registry.example.com/my-app:$(git rev-parse --short HEAD)

# Inspect image layers
docker inspect my-app:latest | jq '.[0].RootFS.Layers | length'
```

### 5. NixOS System Configuration

```nix
# /etc/nixos/configuration.nix — declarative server setup
{ config, pkgs, ... }:

{
  # System basics
  system.stateVersion = "24.05";
  networking.hostName = "my-server";
  time.timeZone = "America/Chicago";

  # User accounts
  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "docker" "sudo" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3... deploy@ci"
    ];
  };

  # Services
  services.nginx = {
    enable = true;
    virtualHosts."app.example.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
        extraConfig = "proxy_read_timeout 60s;";
      };
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    settings = {
      max_connections = 200;
      shared_buffers = "256MB";
      work_mem = "4MB";
    };
    ensureDatabases = [ "myapp" ];
    ensureUsers = [{
      name = "myapp";
      ensureDBOwnership = true;
    }];
  };

  services.redis.servers."".enable = true;

  # Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune.enable = true;

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # Auto-upgrade
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "github:myorg/nixos-config#my-server";
    dates = "04:00";
  };
}
```

```bash
# Apply NixOS configuration
sudo nixos-rebuild switch

# Rollback to previous generation if something breaks
sudo nixos-rebuild switch --rollback

# List all generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Test configuration without applying
sudo nixos-rebuild test
sudo nixos-rebuild dry-activate
```

### 6. CI Pipeline with Nix

```yaml
# .github/workflows/ci.yml — reproducible CI with Nix cache
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@main

      - name: Setup Nix Cache (Magic Nix Cache)
        uses: DeterminateSystems/magic-nix-cache-action@main
        # Automatically caches build outputs to GitHub Actions cache

      - name: Run tests
        run: |
          # All tools come from the flake — no apt-get, no brew, no setup actions
          nix develop --command bash -c "
            npm ci
            npm run test
            npm run build
          "

      - name: Build Docker image
        run: |
          nix build .#dockerImage
          docker load < result

      - name: Security scan
        run: |
          # Nix's dependency graph is fully auditable
          nix build .#dockerImage
          # Generate SBOM from Nix store paths
          nix-store --query --requisites result | sort > sbom.txt
```

```bash
# Use Cachix for shared Nix cache across team
nix-env -iA nixpkgs.cachix
cachix use my-project         # Pull from shared cache
cachix authtoken <token>
nix build .#dockerImage | cachix push my-project   # Push to cache
```

## Key Commands Reference

```bash
# Essential Nix commands
nix develop                    # Enter dev shell
nix develop --command CMD      # Run CMD in dev shell
nix build .#package            # Build a package
nix run .#app -- --args        # Run an app directly
nix shell nixpkgs#curl         # Temporary shell with curl (no install)
nix flake update               # Update all flake inputs
nix flake check                # Validate flake outputs
nix flake show                 # List all outputs

# Search packages
nix search nixpkgs nodejs      # Search nixpkgs
nix-env -qaP | grep python     # Legacy search

# Garbage collection (free disk space)
nix-collect-garbage -d         # Delete all old generations
nix store gc                   # Modern equivalent

# Inspect the Nix store
nix path-info .#dockerImage --recursive  # Show all dependencies
nix show-derivation .#myPackage          # Show build instructions
nix why-depends .#app nixpkgs#glibc      # Why is glibc in the closure?

# Profile management (imperative mode)
nix profile install nixpkgs#htop         # Install to user profile
nix profile list                          # List installed packages
nix profile remove htop                   # Remove

# NixOS
sudo nixos-rebuild switch     # Apply config
sudo nixos-rebuild switch --rollback  # Roll back
nixos-option services.nginx.enable    # Query config value

# Direnv integration
echo "use flake" > .envrc && direnv allow
```

## Common Patterns

### Pattern 1: Pinning a Specific Node.js Version for a Project

```nix
# Useful when different projects need different Node versions
# Project A: Node 18 (legacy app)
# Project B: Node 22 (new app)
# Both work simultaneously without nvm or n

# project-a/flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs_18 ]; # Node 18 only for this project
      };
    };
}

# project-b/flake.nix — same machine, different node version
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs_22 ]; # Node 22 only for this project
      };
    };
}
```

### Pattern 2: Python Development with Poetry

```nix
# Fully reproducible Python environment with Poetry-managed deps
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication;
    in
    {
      packages.${system}.default = mkPoetryApplication {
        projectDir = ./.;
        python = pkgs.python312;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ python312 poetry ruff mypy ];
        shellHook = "poetry install";
      };
    };
}
```

### Pattern 3: Home Manager for Dotfile Management

```nix
# ~/.config/home-manager/home.nix — manage user dotfiles and tools with Nix
{ config, pkgs, ... }:

{
  home.username = "bryan";
  home.homeDirectory = "/Users/localuser";
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    gh ripgrep fd bat eza delta
    jq yq-go httpie
    python312 poetry
    nodejs_22
  ];

  programs.zsh = {
    enable = true;
    shellAliases = {
      ls = "eza --icons";
      cat = "bat";
      grep = "rg";
    };
    initExtra = ''
      eval "$(direnv hook zsh)"
    '';
  };

  programs.git = {
    enable = true;
    userName = "Example User";
    userEmail = "user@example.com";
    delta.enable = true;
    extraConfig.pull.rebase = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
```

```bash
# Apply home-manager config
home-manager switch --flake ~/.config/home-manager#bryan
```

## Pitfalls to Avoid

1. **Mutating the Nix store or using `nix-env -i` in a flake project**: `nix-env -i` installs packages imperatively to your user profile, bypassing the reproducibility benefits. In a flake project, always add packages to `devShells.packages` in `flake.nix` and run `nix develop`. The only exception: one-off tools you need for a few minutes (`nix shell nixpkgs#htop`).

2. **Forgetting to commit `flake.lock`**: The lockfile pins every input's exact git revision and hash. Without committing it, teammates get different versions even if they clone the same repo. Always commit `flake.lock`. Treat it like `package-lock.json` or `Cargo.lock` — it's not optional for reproducibility.

3. **Building non-reproducible derivations**: Nix sandboxes builds by default, but `networking.enable = true;` in a derivation or using `builtins.currentTime` defeats reproducibility. Keep derivations hermetic: all inputs must be declared, no network calls during build, no `date` or `uname` in build scripts. Use `lib.fakeSha256` during first build to get the real hash, then replace it.

## Related Skills

- `docker-expert` — When Nix-built Docker images are deployed into orchestrated containers
- `senior-devops` — Infrastructure-as-code patterns that Nix enables at the system level
- `rust-systems-programming` — Rust projects with `cargo2nix` or `crane` for Nix-reproducible Cargo builds
- `ci-cd-pipeline-builder` — Integrating Nix-based builds into GitHub Actions or GitLab CI

## GitNexus Index

```json
{
  "skill": "nix-reproducible-builds",
  "category": "devops",
  "triggers": ["nix", "nixos", "nix flakes", "nix devshell", "nix home-manager", "reproducible builds", "nix docker", "nix develop", "flake.nix", "nix overlays"],
  "outputs": ["flake.nix", "flake.lock", "devShell", "NixOS configuration.nix", "dockerTools image", "home.nix"],
  "complexity": "high",
  "tools": ["nix", "nixos", "home-manager", "direnv", "cachix", "nix-darwin", "poetry2nix"]
}
```
