# AGENTS.md

## Repository Overview

This repository contains a Nix-based system configuration using nix-darwin (for
macOS).

## Build and Deploy Commands

### macOS (Darwin) Configuration

To rebuild and apply changes to the macOS system:

```bash
rebuild
# or directly
darwin-rebuild switch --flake ~/.config/nix-darwin
```

## Architecture

The repository is organized as follows:

- `flake.nix`: The main entry point that defines inputs and outputs
- `configuration.nix`: Common system configuration (users, packages, etc.)
- `home/`: Home-manager user environment configurations
  - `default.nix`: Main home-manager configuration
  - Topic-specific files: `git.nix`, `shell.nix`, etc.

The configuration uses several Nix features:

1. Flakes for reproducible builds and dependencies
2. Home-manager for user environment management
4. SOPS for secret management

### Secret Management

Secrets are managed using `sops-nix` with:

- Secret definitions in `secrets.yml`
- Age keys for encryption
