# **STATUS:** UNTESTED - not yet validated - DO NOT USE

# Raspberry Pi Bootstrap

A reproducible, single-command bootstrap script for Raspberry Pi OS Lite (64-bit).

This project provides a consistent baseline environment for Raspberry Pi 4 / 5 systems, turning a fresh OS install into a fully provisioned development node with Docker, Tailscale, Conda, JupyterLab, and standard CLI tooling.

The goal is simplicity and repeatability:

> Flash OS → Run one command → Reboot → Done

No configuration branches. No role-based variants. No hidden options.

---

## Design Goals

- Consistent environment across all Raspberry Pi devices
- One-command installation
- No interactive prompts
- No secrets embedded in the script
- Safe to re-run (idempotent where practical)
- Avoid device-specific configuration (hostname, SSH keys, etc.)
- Works on Raspberry Pi OS Lite (Debian-based, 64-bit ARM)

---

## Target Platform

- Raspberry Pi OS Lite (64-bit recommended)
- Raspberry Pi 4 or Raspberry Pi 5
- arm64 / aarch64 architecture

The script will abort if run on:
- 32-bit ARM (armv7/armv6)
- x86_64
- Non-Debian systems

---

## Installation (On a Fresh Pi)

### 1. Flash OS

Flash **Raspberry Pi OS Lite (64-bit)** to microSD or NVMe.

Enable SSH during imaging if desired.

### 2. First Boot

- Boot the Pi
- Ensure network access
- SSH into the device

### 3. Run the Bootstrap Script

```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/pi-bootstrap/main/raspi-bootstrap.sh | sudo bash
```

### 4. Reboot

```bash
sudo reboot
```

---

## Post-Boot Smoke Tests

After reboot:

### Docker

```bash
docker run --rm hello-world
```

If you receive a permission error, log out and back in (or reboot again).

### Tailscale (manual authentication)

```bash
sudo tailscale up
```

Follow the browser-based login flow.

### Conda

```bash
conda --version
```

### JupyterLab

```bash
jupyter lab --version
```

---

## What Gets Installed

### Core System Tools

- ca-certificates
- curl
- wget
- git
- openssh-server (enabled)
- neovim
- tmux
- htop
- jq
- ripgrep
- fzf
- tree
- rsync
- unzip
- zip
- gnupg
- lsb-release
- software-properties-common
- build-essential
- python3
- python3-venv
- python3-pip

---

### Docker

Installed via official Docker convenience script:

- Docker Engine
- Docker CLI
- Docker Compose plugin
- Docker service enabled and started
- User added to `docker` group

---

### Tailscale

Installed via official Tailscale installer:

- tailscaled service enabled and started
- Not automatically authenticated
- Requires manual `sudo tailscale up`

---

### Conda (Miniforge)

Installed to:

```
/opt/conda
```

Features:

- Miniforge (conda-forge based)
- System-wide PATH configuration
- Base environment updated
- Auto-activation of base disabled

---

### Python Dev Stack (via Conda Base Environment)

Installed packages:

- jupyterlab
- ipykernel
- numpy
- pandas
- pyarrow
- requests
- lxml

An IPython kernel named:

```
Python (conda-base)
```

is registered for Jupyter.

---

## Quality-of-Life Defaults

- Default editor set to `nvim`
- `/etc/profile.d/conda.sh` created for PATH configuration
- `/etc/profile.d/editor.sh` sets `EDITOR` and `VISUAL`
- `~/bin` directory created for the user
- Informational MOTD block added

---

## What This Script Intentionally Does NOT Do

- Does NOT copy private SSH keys
- Does NOT auto-authenticate Tailscale
- Does NOT change hostname
- Does NOT modify user dotfiles
- Does NOT format or mount NVMe drives
- Does NOT install project-specific software
- Does NOT create multiple environment profiles

This keeps the bootstrap generic and safe.

---

## Philosophy

This repository provides infrastructure glue — not project code.

All project logic should live in separate repositories.

The Raspberry Pi should be disposable:

- If a microSD fails → reflash → run bootstrap → continue working.
- GitHub remains the source of truth for code.
- The device remains a reproducible tool, not a handcrafted artifact.

---

## Updating the Bootstrap

If you update `raspi-bootstrap.sh`:

```bash
git add raspi-bootstrap.sh
git commit -m "Update bootstrap"
git push
```

All future Pi installs will use the updated script automatically.

---

## Versioning

This project currently operates as a rolling `main` branch.

You may optionally introduce tagged releases in the future if strict version pinning becomes necessary.

