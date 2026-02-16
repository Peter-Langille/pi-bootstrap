# **STATUS:** Tested on: Pi 5, Raspberry Pi OS Debian 13 (trixie), 2/16/26, results - PASS.

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


============================================================
SSH HOST KEY CHANGED AFTER REFLASH — RESOLUTION GUIDE
============================================================

PURPOSE
-------
When you reflash a Raspberry Pi SD card and reuse the same
hostname or IP address, SSH will detect a host key mismatch.

This guide explains:
- Why it happens
- How to fix it safely
- How to avoid future confusion

------------------------------------------------------------
WHY THIS HAPPENS
------------------------------------------------------------

Each OS installation generates unique SSH host keys:

/etc/ssh/ssh_host_*

When you:
- Reflash the SD card
- Reinstall the OS
- Keep the same hostname or IP

The new system generates NEW host keys.

Your laptop still remembers the OLD key in:

~/.ssh/known_hosts

SSH then warns:

"REMOTE HOST IDENTIFICATION HAS CHANGED!"

This is a security feature to prevent man-in-the-middle attacks.

------------------------------------------------------------
WHEN IT IS SAFE TO PROCEED
------------------------------------------------------------

It is safe to proceed IF:

- You intentionally reflashed the SD card
- You control the LAN
- You expect the host key to change

If you did NOT reflash and see this warning,
investigate before proceeding.

------------------------------------------------------------
STEP 1 — REMOVE THE OLD HOST KEY ENTRY
------------------------------------------------------------

Use the exact command SSH suggests:

ssh-keygen -R <hostname-or-ip>

Example (hostname):

ssh-keygen -R pi5-dev-4.local

Example (IP address):

ssh-keygen -R 192.168.1.42

This removes the old fingerprint from:

~/.ssh/known_hosts

------------------------------------------------------------
STEP 2 — RECONNECT
------------------------------------------------------------

ssh user@hostname

Example:

ssh peter@pi5-dev-4.local

You will see:

"The authenticity of host ... can't be established."
Type:

yes

This stores the new host key.

Connection proceeds normally.

------------------------------------------------------------
VERIFY NEW HOST KEY ENTRY (OPTIONAL)
------------------------------------------------------------

To confirm it was added:

ssh-keygen -F pi5-dev-4.local

This shows the new stored fingerprint.

------------------------------------------------------------
ADVANCED: MANUAL CLEANUP IF NEEDED
------------------------------------------------------------

If the automatic removal fails:

Open the file:

nvim ~/.ssh/known_hosts

Locate the offending line (SSH tells you the line number)
and delete it manually.

Save and retry SSH.

------------------------------------------------------------
MULTIPLE SD CARDS WITH SAME HOSTNAME
------------------------------------------------------------

If you frequently swap SD cards that share
the same hostname, you will see this warning
each time the OS differs.

Best practice:
- Give each SD card a unique hostname
OR
- Accept that you'll need to remove the key
  whenever switching images

------------------------------------------------------------
BEST PRACTICE FOR BOOTSTRAP TESTING
------------------------------------------------------------

When testing a new SD image:

1) Expect host key warning
2) Run ssh-keygen -R <hostname>
3) Reconnect and accept new fingerprint
4) Proceed with bootstrap

This is normal infrastructure behavior.

------------------------------------------------------------
SUMMARY
------------------------------------------------------------

Reflashing regenerates SSH host keys.
SSH warns because it protects you.

Resolution:
ssh-keygen -R <host>
Reconnect
Type "yes"

Continue working.
============================================================
------------------------------------------------------------
Nice Layer (Optional)
------------------------------------------------------------

Script:
extras/raspi-nice-setup_v5.sh

Purpose:
Applies user-level development quality-of-life configuration
after bootstrap.

Design Principles:
- Idempotent (safe to re-run)
- Never writes into user home as root
- All home writes performed via sudo -u target user
- Font install is best-effort and non-fatal
- No GitHub API dependency
- No jq dependency
- Uses stable Nerd Font release URL

Font Install Behavior:
- Downloads FiraCode Nerd Font from:
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz
- Extracts into:
  ~/.local/share/fonts/FiraCodeNerdFont
- Runs fc-cache
- Will warn but not fail if network interruption occurs

Run:
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/extras/raspi-nice-setup_v5.sh | sudo bash

Operational Notes:
- New SSH session required after run.
- Nerd Font must also be installed on client machine
  (icons render on the terminal host, not the Pi).

