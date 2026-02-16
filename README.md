# **STATUS:** UNTESTED - not yet validated - DO NOT USE

# Raspberry Pi Bootstrap

A reproducible, single-command bootstrap script for Raspberry Pi OS (Lite or Full, 64-bit).

This project provides a consistent baseline environment for Raspberry Pi 4 / 5 systems, turning a fresh OS install into a fully provisioned development node with Docker, Tailscale, Conda, JupyterLab, and an ML-lite stack suitable for real-time inference workloads.

The goal is simplicity and repeatability:

> Flash OS → Run one command → Reboot → Done

No configuration branches. No role-based variants. No interactive options.

---

## Supported Platform

- Raspberry Pi OS Lite (64-bit recommended)
- Raspberry Pi OS Full (64-bit supported)
- Raspberry Pi 4 / 5
- arm64 / aarch64 architecture

The script will abort if run on:
- 32-bit ARM
- x86_64
- Non-Debian-based systems

---

## Installation (Fresh Pi)

### 1. Flash OS

Flash **Raspberry Pi OS 64-bit** (Lite or Full) to microSD or NVMe.

Enable SSH during imaging if desired.

### 2. First Boot

- Boot the Pi
- Ensure network access
- SSH into the device

### 3. Run the Bootstrap Script

For ML-lite version:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/pi-bootstrap/main/raspi-bootstrap_v2_mllite.sh | sudo bash
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

### Tailscale

```bash
sudo tailscale up
```

Follow browser-based authentication.

### Conda

```bash
conda --version
```

### JupyterLab

```bash
jupyter lab --version
```

### ML-lite Verification

```bash
/opt/conda/bin/python -c "import sklearn, xgboost, lightgbm, joblib"
/opt/conda/bin/python -c "import onnxruntime as ort; print(ort.__version__)"
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

Installed via official installer:

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

## Python / Data Stack (Base Environment)

Installed into conda base environment:

### Core Data Libraries

- numpy
- pandas
- pyarrow
- requests
- lxml
- pyyaml
- matplotlib
- ipykernel
- jupyterlab

### ML-lite Stack (Inference + Light Training)

- scikit-learn
- xgboost
- lightgbm
- joblib
- onnxruntime

This stack is suitable for:

- Classical ML training
- Tree-based boosting
- Real-time model inference
- Loading serialized models in transform pipelines
- ONNX-based portable inference

TensorFlow and PyTorch are intentionally not installed by default.

---

## Quality-of-Life Defaults

- Default editor set to `nvim`
- `/etc/profile.d/conda.sh` created for PATH configuration
- `/etc/profile.d/editor.sh` sets `EDITOR` and `VISUAL`
- `~/bin` directory created for user

---

## What This Script Does NOT Do

- Does NOT copy private SSH keys
- Does NOT auto-authenticate Tailscale
- Does NOT change hostname
- Does NOT modify user dotfiles
- Does NOT format or mount NVMe drives
- Does NOT install deep learning frameworks (TensorFlow / PyTorch)

---

## Philosophy

This repository provides infrastructure glue — not project code.

All project logic should live in separate repositories.

The Raspberry Pi should be disposable:

- If a microSD fails → reflash → run bootstrap → continue working.
- GitHub remains the source of truth for code.
- Devices remain reproducible tools, not handcrafted artifacts.

---

## Updating the Bootstrap

After modifying the script:

```bash
git add raspi-bootstrap_v2_mllite.sh README.md
git commit -m "Update ML-lite bootstrap and documentation"
git push
```

Future installs will automatically use the updated version.

---

## Versioning

Currently operating on rolling `main`.

Tag releases if strict reproducibility is required.

