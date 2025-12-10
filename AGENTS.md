# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Repository Overview

This repository contains a Nix-based system configuration using nix-darwin (for
macOS), NixOS (for Linux), and home-manager. It's structured as a flake with
different configurations for:

1. Darwin (macOS) system configuration
2. Linux system configuration
3. Homelab server configuration
4. Home-manager user environment

## Build and Deploy Commands

### macOS (Darwin) Configuration

To rebuild and apply changes to the macOS system:

```bash
rebuild
# or directly
darwin-rebuild switch --flake ~/.config/nix-darwin
```

### Linux Configurations

For the primary Linux system:

```bash
nixos-rebuild switch --flake .#nixos
```

For the homelab server:

```bash
lab-deploy
# or directly
nixos-rebuild switch --flake .#homelab --target-host homelab --build-host homelab --fast
```

## Architecture

The repository is organized as follows:

- `flake.nix`: The main entry point that defines inputs and outputs
- `configuration.nix`: Common system configuration (users, packages, etc.)
- `darwin/`: macOS-specific configurations (sketchybar, aerospace, etc.)
- `home/`: Home-manager user environment configurations
  - `default.nix`: Main home-manager configuration
  - Topic-specific files: `vim.nix`, `git.nix`, `shell.nix`, etc.
- `linux/`: NixOS configuration for the main Linux system
- `lab/`: NixOS configuration for the homelab server

The configuration uses several Nix features:

1. Flakes for reproducible builds and dependencies
2. Home-manager for user environment management
3. Stylix for consistent theming
4. SOPS for secret management

## Noteworthy Subsystems

### Matrix Server (Homelab)

The homelab configuration includes a Matrix Synapse server setup with PostgreSQL
database.

### Secret Management

Secrets are managed using `sops-nix` with:

- Secret definitions in `secrets.yml`
- Age keys for encryption

