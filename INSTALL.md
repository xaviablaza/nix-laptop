# NixOS Laptop Installation Guide

Step-by-step guide for deploying NixOS onto a laptop using `nixos-anywhere`, rebuilding into the full desktop configuration, and setting up the Navegante development environment.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Phase 1: Deploy Minimal NixOS via nixos-anywhere](#phase-1-deploy-minimal-nixos-via-nixos-anywhere)
  - [Prepare the Target Laptop](#prepare-the-target-laptop)
  - [Run the Deployment Script](#run-the-deployment-script)
- [Phase 2: Rebuild into Full Desktop Configuration](#phase-2-rebuild-into-full-desktop-configuration)
  - [Log into the Laptop](#log-into-the-laptop)
  - [Run rebuild-laptop](#run-rebuild-laptop)
  - [Reboot into Configuration 2](#reboot-into-configuration-2)
- [Phase 3: Set Up the Navegante Dev Flake](#phase-3-set-up-the-navegante-dev-flake)
  - [Enable direnv](#enable-direnv)
  - [Clone the Navegante Web Repo](#clone-the-navegante-web-repo)
  - [Configure direnv for the Project](#configure-direnv-for-the-project)
  - [Install Ruby Dependencies](#install-ruby-dependencies)
  - [Start Development Services](#start-development-services)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Overview

The installation follows three phases:

1. **Deploy minimal NixOS** -- Use `nixos-anywhere` to remotely install a minimal NixOS configuration onto any Linux laptop over the network. This minimal config (the `nix-laptop` flake target) includes just enough to boot, connect to the network, and rebuild.

2. **Rebuild into the full configuration** -- Log into the laptop and run `rebuild-laptop`, which triggers `nixos-rebuild switch --flake /etc/nixos#nix-laptop`. This builds and activates the full desktop environment with niri, development tools, and all system dependencies.

3. **Set up the Navegante dev flake** -- Configure `direnv` and the project's Nix flake to get a fully reproducible development environment with PostgreSQL, Redis, Ruby, Node.js, and helper scripts.

## Prerequisites

- A host machine with Nix installed (with flakes enabled)
- The target laptop running any Linux distribution (or a NixOS live ISO) with SSH access enabled
- Both machines on the same network
- The `nix-laptop` flake repository cloned on the host machine

## Phase 1: Deploy Minimal NixOS via nixos-anywhere

### Prepare the Target Laptop

The target laptop needs to be running any Linux with SSH enabled. This can be a live NixOS ISO, an existing Linux install, or any distribution -- `nixos-anywhere` will overwrite the disk entirely.

1. Boot the laptop into a Linux environment
2. Ensure SSH is running and you know the IP address:

```bash
ip addr show
```

3. Ensure the `administrator` user can be accessed via SSH (or adjust the deployment script accordingly)

### Run the Deployment Script

From your **host machine**, navigate to the `nix-laptop` flake directory and run the deployment script:

```bash
cd nixos-configurations/nix-laptop
```

The `deploy-nixos.sh` script uses `nixos-anywhere` to remotely install the `nix-laptop` configuration:

```bash
# Edit deploy-nixos.sh to set the correct SSH password and target IP
# SSHPASS=<password> and administrator@<laptop-ip>
vim deploy-nixos.sh

# Run the deployment
./deploy-nixos.sh
```

The script does the following:
- Connects to the target laptop over SSH
- Partitions and formats the disk using disko (declarative disk configuration)
- Auto-generates the hardware configuration for the target machine
- Installs the minimal `nix-laptop` NixOS configuration
- Sets up the bootloader and base system

This will take some time depending on network speed and hardware. Once complete, the laptop will be running a minimal NixOS with niri compositor, basic networking, and SSH access.

## Phase 2: Rebuild into Full Desktop Configuration

### Log into the Laptop

After `nixos-anywhere` completes, the laptop will reboot into the minimal NixOS configuration. Log in either directly at the console or via SSH:

```bash
ssh administrator@<laptop-ip>
```

The minimal configuration pre-loads the full laptop flake into `/etc/nixos` (symlinked from `/home/administrator/nixos-config`), so all the dependencies for the full build are already referenced.

### Run rebuild-laptop

The system comes with a shell alias `rebuild-laptop` that rebuilds into the full nix-laptop desktop configuration:

```bash
rebuild-laptop
```

This runs:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nix-laptop
```

The rebuild will download and build the full desktop environment including niri, development tools, and all system packages. This step will take a while on the first run.

### Reboot into Configuration 2

Once the rebuild completes, reboot to activate the full configuration:

```bash
sudo reboot
```

After rebooting, you will be in the full nix-laptop desktop environment with niri compositor, all configured applications, and development tools ready.

## Phase 3: Set Up the Navegante Dev Flake

The Navegante project uses a Nix dev flake that provides a complete, reproducible development environment (PostgreSQL 17, Redis, Ruby 3.4.7, Node.js, Playwright, and helper scripts). We use `direnv` to automatically activate this environment when you enter the project directory.

### Enable direnv

Add direnv to your NixOS system configuration. Open your `configuration.nix` and add:

```nix
programs.direnv.enable = true;
```

**Important**: Use `programs.direnv.enable`, not `environment.systemPackages`. The NixOS module sets up the shell integration automatically.

Rebuild your system to apply:

```bash
rebuild-laptop
```

### Clone the Navegante Web Repo

If you have not already, clone the repository:

```bash
git clone <navegante-web-repo-url>
```

### Configure direnv for the Project

1. `cd` into the `navegante_web` directory:

```bash
cd navegante_web
```

2. Create a `.envrc` file in the project root:

```bash
echo "use flake" > .envrc
```

3. Leave and re-enter the directory so direnv detects the new `.envrc`:

```bash
cd ..
cd navegante_web
```

4. direnv will prompt you to allow the configuration. Run what the terminal tells you:

```bash
direnv allow .
```

If everything is set up correctly, you should see the "Navegante Web -nix flake-" message appear along with a list of available helper scripts (like `services-start`, `services-stop`, `services-status`, etc.).

### Install Ruby Dependencies

Once the dev flake is active, install the Ruby gem dependencies:

```bash
bundle install
```

### Start Development Services

Use the helper scripts provided by the flake to start PostgreSQL and Redis:

```bash
services-start
```

Then initialize the database:

```bash
init-database
bin/rails db:create db:migrate db:seed
```

You are now ready to develop. Available flake helper commands:

| Command | Description |
|---|---|
| `services-start` | Start PostgreSQL and Redis |
| `services-stop` | Stop PostgreSQL and Redis |
| `services-status` | Check service status |
| `pg-start` / `pg-stop` / `pg-status` | PostgreSQL controls |
| `redis-start` / `redis-stop` / `redis-status` | Redis controls |
| `init-database` | Create the development database |
| `clean-rebuild` | Clean all state and reinstall deps |

## Troubleshooting

### nixos-anywhere Deployment Fails

**Connection refused:**
- Verify SSH is running on the target: `systemctl status sshd`
- Check the target IP address: `ip addr show`
- Ensure password authentication is enabled in sshd config

**Disk partitioning errors:**
- The target disk must be the expected device (check `lsblk` on the target)
- Ensure the disk is not mounted or in use

### rebuild-laptop Fails

**Flake not found:**
- Verify the symlink exists: `ls -la /etc/nixos`
- It should point to `/home/administrator/nixos-config`
- If missing, create it: `sudo ln -sf /home/administrator/nixos-config /etc/nixos`

**Build errors:**
- Run with trace for detailed output:
  ```bash
  sudo nixos-rebuild switch --flake /etc/nixos#nix-laptop --show-trace
  ```
- Check network connectivity (flake inputs need to be fetched)

### direnv Not Activating

**"direnv: error .envrc is blocked":**
- Run `direnv allow .` in the project directory

**direnv command not found:**
- Ensure `programs.direnv.enable = true` is in your configuration (not in `environment.systemPackages`)
- Rebuild and open a new terminal session

**Flake message does not appear:**
- Ensure the `.envrc` file contains exactly `use flake`
- Verify `navegante_web/flake.nix` exists
- Try `cd ..` then `cd navegante_web` again

### Service Issues

**PostgreSQL won't start:**
- Check logs: `cat navegante_web/.nix-state/postgres/postgres.log`
- Try a clean rebuild: `clean-rebuild`

**Redis won't start:**
- Check logs: `cat navegante_web/.nix-state/redis/redis.log`
- Check if the port is already in use: `ss -tlnp | grep 6379`

## Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nixos-anywhere Documentation](https://github.com/nix-community/nixos-anywhere)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [direnv](https://direnv.net/)
- [disko - Declarative Disk Partitioning](https://github.com/nix-community/disko)
- [niri Compositor](https://github.com/YaLTeR/niri)
