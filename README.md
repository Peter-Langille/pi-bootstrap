# **STATUS:** UNTESTED - not yet validated - DO NOT USE

# Raspberry Pi Bootstrap

A reproducible, single-command bootstrap script for Raspberry Pi OS (Lite or Full, 64-bit).

This project provides a consistent baseline environment for Raspberry Pi 4 / 5 systems, turning a fresh OS install into a fully provisioned development node with Docker, Tailscale, Conda (Miniforge), JupyterLab, and an ML-lite stack suitable for real-time inference workloads.

Goal:

Flash OS → Run one command → Reboot → Done

No configuration branches. No role-based variants. No interactive options.

------------------------------------------------------------
SUPPORTED PLATFORM
------------------------------------------------------------

- Raspberry Pi OS Lite (64-bit recommended)
- Raspberry Pi OS Full (64-bit supported)
- Raspberry Pi 4 / 5
- arm64 / aarch64 architecture

The script will abort if run on:
- 32-bit ARM
- x86_64
- Non-Debian-based systems

------------------------------------------------------------
INSTALLATION (FRESH PI)
------------------------------------------------------------

1) Flash OS

Flash Raspberry Pi OS 64-bit (Lite or Full) to microSD or NVMe.
Enable SSH during imaging if desired.

2) First Boot

- Boot the Pi
- Ensure network access
- SSH into the device

3) Run the Bootstrap Script (ML-lite)

curl -fsSL https://raw.githubusercontent.com/Peter-Langille/pi-bootstrap/main/raspi-bootstrap_v2_mllite.sh | sudo bash

4) Reboot

sudo reboot

------------------------------------------------------------
POST-BOOT SMOKE TESTS
------------------------------------------------------------

Docker:

docker run --rm hello-world

If you receive a permission error, log out and back in (or reboot again).

Tailscale:

sudo tailscale up

Follow browser-based authentication.

Conda:

conda --version

JupyterLab:

jupyter lab --version

ML-lite Verification (explicit conda python):

/opt/conda/bin/python -c "import sklearn, xgboost, lightgbm, joblib"
/opt/conda/bin/python -c "import onnxruntime as ort; print(ort.__version__)"

------------------------------------------------------------
WHAT GETS INSTALLED
------------------------------------------------------------

Core System Tools (apt):

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

------------------------------------------------------------
DOCKER
------------------------------------------------------------

Installed via official Docker convenience script:

- Docker Engine
- Docker CLI
- Docker Compose plugin
- Docker service enabled and started
- User added to docker group

------------------------------------------------------------
TAILSCALE
------------------------------------------------------------

Installed via official installer:

- tailscaled service enabled and started
- Not automatically authenticated
- Requires manual sudo tailscale up

------------------------------------------------------------
CONDA (MINIFORGE)
------------------------------------------------------------

Installed to:

/opt/conda

Features:

- Miniforge (conda-forge based)
- System-wide PATH configuration via /etc/profile.d/conda.sh
- Base environment updated
- Auto-activation of base disabled

------------------------------------------------------------
PYTHON / DATA / ML-LITE STACK
------------------------------------------------------------

Installed into the conda base environment:

Core Data + Notebook:

- jupyterlab
- ipykernel
- numpy
- pandas
- pyarrow
- requests
- lxml
- matplotlib
- pyyaml

ML-lite (inference + light training):

- scikit-learn
- xgboost
- lightgbm
- joblib
- onnxruntime

This stack supports:

- Classical ML training
- Tree-based boosting
- Real-time model inference in transform pipelines
- Loading serialized models (joblib)
- ONNX-based portable inference

TensorFlow and PyTorch are intentionally NOT installed by default.

------------------------------------------------------------
QUALITY-OF-LIFE DEFAULTS
------------------------------------------------------------

- Default editor set to nvim
- ~/bin directory created for the user
- Conda PATH available in login shells via /etc/profile.d/conda.sh

------------------------------------------------------------
WHAT THIS SCRIPT DOES NOT DO
------------------------------------------------------------

- Does NOT copy private SSH keys
- Does NOT auto-authenticate Tailscale
- Does NOT change hostname
- Does NOT modify user dotfiles
- Does NOT format or mount NVMe drives
- Does NOT install deep learning frameworks (TensorFlow / PyTorch)

------------------------------------------------------------
PHILOSOPHY
------------------------------------------------------------

This repository provides infrastructure glue — not project code.

All project logic should live in separate repositories.

The Raspberry Pi should be disposable:

If a microSD fails → reflash → run bootstrap → continue working.
GitHub remains the source of truth for code.
Devices remain reproducible tools, not handcrafted artifacts.

------------------------------------------------------------
UPDATING THE BOOTSTRAP
------------------------------------------------------------

After modifying the script or documentation:

git add raspi-bootstrap_v2_mllite.sh README.md
git commit -m "Fix conda python checks and document ML-lite verification"
git push

------------------------------------------------------------
VERSIONING
------------------------------------------------------------

Currently operating on rolling main branch.

Tag releases if strict reproducibility is required.

