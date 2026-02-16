# **STATUS:** UNTESTED - not yet validated - DO NOT USE
# Raspberry Pi Bootstrap

A reproducible, single-command bootstrap script for Raspberry Pi OS (Lite or Full, 64-bit) aligned with Debian 13 (trixie).

This project provides a consistent baseline environment for Raspberry Pi 4 / 5 systems, turning a fresh OS install into a fully provisioned development node with Docker, Tailscale, Conda (Miniforge), JupyterLab, and an ML-lite stack suitable for real-time inference workloads.

Goal:

Flash OS → Run one command → Reboot → Done

No configuration branches.
No role-based variants.
No interactive prompts during install.

------------------------------------------------------------
SUPPORTED PLATFORM
------------------------------------------------------------

- Raspberry Pi OS Lite (64-bit recommended)
- Raspberry Pi OS Full (64-bit supported)
- Debian 13 (trixie) on Raspberry Pi hardware
- arm64 / aarch64 architecture only

The script will abort if run on:
- 32-bit ARM
- x86_64
- Non-Debian-based systems

------------------------------------------------------------
INSTALLATION (FRESH PI)
------------------------------------------------------------

1) Flash OS

Flash Raspberry Pi OS 64-bit (Lite or Full).
Set hostname and enable SSH during imaging.

2) First Boot

- Boot the Pi
- Ensure network access
- SSH into the device

3) Run the Bootstrap Script (v3 ML-lite)

curl -fsSL https://raw.githubusercontent.com/Peter-Langille/pi-bootstrap/main/raspi-bootstrap_v3_mllite_trixie.sh | sudo bash

4) Reboot

sudo reboot

------------------------------------------------------------
POST-BOOT SMOKE TESTS
------------------------------------------------------------

Docker:

docker run --rm hello-world

Tailscale:

sudo tailscale up

Conda:

conda --version

JupyterLab:

jupyter lab --version

ML-lite Verification:

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
- build-essential
- python3
- python3-venv
- python3-pip

Note:
software-properties-common is intentionally NOT installed.
It is not required and is not available in many Debian 13 (trixie) setups.

------------------------------------------------------------
APT HARDENING
------------------------------------------------------------

The bootstrap performs a fully non-interactive system upgrade.

It uses dpkg options to:

- Automatically accept default config handling
- Preserve existing configuration files
- Prevent blocking prompts during upgrade

This ensures the script runs unattended on both Lite and Full OS installs.

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
- Base environment updated
- Auto-activation of base disabled
- PATH available via /etc/profile.d/conda.sh

------------------------------------------------------------
PYTHON / DATA / ML-LITE STACK
------------------------------------------------------------

Installed into conda base environment:

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

ML-lite:

- scikit-learn
- xgboost
- lightgbm
- joblib
- onnxruntime

Designed for:

- Classical ML training
- Tree-based boosting
- Real-time model inference
- Transform-stage model execution
- ONNX runtime inference

Deep learning frameworks (TensorFlow, PyTorch) are intentionally NOT installed by default.

------------------------------------------------------------
QUALITY-OF-LIFE DEFAULTS
------------------------------------------------------------

- Default editor set to nvim
- ~/bin directory created
- SSH enabled

------------------------------------------------------------
WHAT THIS SCRIPT DOES NOT DO
------------------------------------------------------------

- Does NOT copy private SSH keys
- Does NOT auto-authenticate Tailscale
- Does NOT change hostname
- Does NOT modify user dotfiles
- Does NOT format or mount NVMe drives
- Does NOT install TensorFlow or PyTorch

------------------------------------------------------------
PHILOSOPHY
------------------------------------------------------------

The Raspberry Pi should be disposable infrastructure.

If a microSD fails:

Reflash → Run bootstrap → Continue working.

All project code belongs in separate repositories.
This repository exists to standardize infrastructure only.

------------------------------------------------------------
VERSIONING
------------------------------------------------------------

Current authoritative script:

raspi-bootstrap_v3_mllite_trixie.sh

Future versions should increment the version number.

