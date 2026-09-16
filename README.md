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
curl -fsSL https://raw.githubusercontent.com/Peter-Langille/pi-bootstrap/main/extras/raspi-nice-setup_v5.sh | sudo bash

Operational Notes:
- New SSH session required after run.
- Nerd Font must also be installed on client machine
  (icons render on the terminal host, not the Pi).


------------------------------------------------------------
RASPBERRY PI 3 A+ — EXPERIMENTAL / UNPROVEN
------------------------------------------------------------

STATUS:

EXPERIMENTAL / UNPROVEN

Target hardware:
- Raspberry Pi 3 A+
- 512 MB RAM
- Raspberry Pi OS / Debian 13 (trixie)
- 64-bit ARM / aarch64

First clean validation target:
- pi3-dev-2

Script:
raspi-bootstrap_v4_pi3_mllite_trixie.sh

Required explicit package lock:
locks/pi3-ml-linux-aarch64-explicit.txt

IMPORTANT:
This Pi 3 bootstrap has NOT yet completed a clean end-to-end deployment.
Do not treat it as a proven bootstrap until it passes validation on a freshly
imaged Raspberry Pi 3 A+.

WHY A SEPARATE PI 3 BOOTSTRAP EXISTS:

The standard v3 ML-lite bootstrap performs a Conda dependency solve while
installing the development/ML stack.

Testing on a Raspberry Pi 3 A+ with 512 MB RAM demonstrated that this solve is
not practical on the device. Conda exhausted available memory, entered heavy
swap/I/O activity, and was eventually killed/rebooted.

The Pi 3 bootstrap therefore uses a different Conda strategy.

PI 3 DESIGN:

1) Persistent swap

The script creates:

/swapfile

Size:

2 GB

The swapfile is:
- Created before apt/Conda workloads
- Configured with chmod 600
- Initialized with mkswap
- Enabled with swapon
- Persisted through /etc/fstab

Existing Raspberry Pi zram is left enabled and untouched.

If /swapfile already exists, the script validates it before attempting to use
it and refuses to overwrite an existing file that is not valid swap.

2) Clean Miniforge base

Miniforge is installed at:

/opt/conda

The ML/data stack is NOT installed into Conda base.

Base auto-activation is disabled.

3) Dedicated ML environment

The ML/data environment is:

/opt/conda/envs/pi3-ml

It contains:

- Python 3.13
- JupyterLab
- ipykernel
- numpy
- pandas
- pyarrow
- requests
- lxml
- matplotlib
- pyyaml
- scikit-learn
- xgboost
- lightgbm
- joblib
- onnxruntime

4) Explicit ARM64 package lock

The environment is created from:

locks/pi3-ml-linux-aarch64-explicit.txt

This explicit package specification was generated from a successfully solved
linux-aarch64 pi3-ml environment on a Raspberry Pi 5.

The Pi 3 therefore installs exact package artifacts instead of performing the
large dependency solve locally.

This is specifically intended to avoid the memory-intensive Conda solve that
failed on the Raspberry Pi 3 A+.

5) Jupyter

The pi3-ml environment is registered as:

Python (pi3-ml)

Jupyter and JupyterLab commands are exposed from the dedicated pi3-ml
environment rather than from Conda base.

------------------------------------------------------------
PI 3 TEST PROCEDURE
------------------------------------------------------------

On a freshly imaged Raspberry Pi 3 A+:

git clone git@github.com:Peter-Langille/pi-bootstrap.git

cd pi-bootstrap

sudo bash raspi-bootstrap_v4_pi3_mllite_trixie.sh

After successful completion:

sudo reboot

Then verify:

swapon --show

docker run --rm hello-world

sudo tailscale up

/opt/conda/envs/pi3-ml/bin/python -c "import numpy, pandas, pyarrow, requests, lxml, matplotlib, yaml, sklearn, xgboost, lightgbm, joblib, onnxruntime; print('PASS')"

/opt/conda/envs/pi3-ml/bin/jupyter lab --version

------------------------------------------------------------
PI 3 PROMOTION CRITERIA
------------------------------------------------------------

raspi-bootstrap_v4_pi3_mllite_trixie.sh remains EXPERIMENTAL / UNPROVEN until
a clean deployment on pi3-dev-2 proves:

- Bootstrap completes without OOM failure
- 2 GB /swapfile survives reboot
- Raspberry Pi zram remains available
- Docker works
- Tailscale installs and authenticates normally
- Miniforge base remains functional
- pi3-ml environment installs successfully from the explicit lock
- ML/data import validation passes
- JupyterLab starts from the pi3-ml environment
- Python (pi3-ml) Jupyter kernel is registered

Only after those checks pass should the Pi 3 bootstrap be documented as
PROVEN.

------------------------------------------------------------
NEWSBOAT + w3m — TERMINAL NEWS READER
------------------------------------------------------------

STATUS:

Tested on Raspberry Pi OS / Debian 13 (trixie) — PASS.

Newsboat and w3m are installed and configured automatically by:

extras/raspi-nice-setup_v5.sh

Newsboat provides a terminal-based RSS news reader.

w3m provides a terminal-based web browser so full articles can be opened
directly from Newsboat without requiring a graphical desktop or browser.


------------------------------------------------------------
INSTALLATION
------------------------------------------------------------

Normally no separate installation is required because the Nice Layer installs:

- newsboat
- w3m

and creates the required configuration files automatically.

Manual installation if needed:

sudo apt update
sudo apt install newsboat w3m


------------------------------------------------------------
IMPORTANT FILE LOCATIONS
------------------------------------------------------------

RSS feed list:

~/.config/newsboat/urls

Newsboat configuration:

~/.config/newsboat/config

The Nice Layer automatically creates both files.

DO NOT put Newsboat configuration commands in the urls file.
Newsboat will interpret them as RSS feeds.


------------------------------------------------------------
CONFIGURED RSS FEEDS
------------------------------------------------------------

The Nice Layer installs the following feed list:

# --- GENERAL / WORLD NEWS ---
https://feeds.bbci.co.uk/news/rss.xml news general
https://feeds.bbci.co.uk/news/world/rss.xml news world
https://feeds.npr.org/1001/rss.xml news general
https://www.theguardian.com/world/rss news world

# --- US NEWS ---
https://feeds.npr.org/1003/rss.xml news usa
https://rss.nytimes.com/services/xml/rss/nyt/US.xml news usa

# --- BUSINESS / ECONOMY ---
https://feeds.bbci.co.uk/news/business/rss.xml news business
https://feeds.npr.org/1017/rss.xml news business
https://rss.nytimes.com/services/xml/rss/nyt/Business.xml news business

# --- SCIENCE ---
https://feeds.bbci.co.uk/news/science_and_environment/rss.xml science
https://feeds.npr.org/1007/rss.xml science
https://rss.nytimes.com/services/xml/rss/nyt/Science.xml science
https://www.nasa.gov/rss/dyn/breaking_news.rss science space

# --- TECHNOLOGY ---
https://feeds.bbci.co.uk/news/technology/rss.xml tech
https://feeds.arstechnica.com/arstechnica/index tech
https://www.theverge.com/rss/index.xml tech
https://www.wired.com/feed/rss tech

# --- LINUX / OPEN SOURCE ---
https://www.phoronix.com/rss.php linux
https://lwn.net/headlines/rss linux
https://www.raspberrypi.com/news/feed/ raspberrypi linux
https://ubuntu.com/blog/feed linux ubuntu

# --- ELECTRONICS / MAKER ---
https://hackaday.com/blog/feed/ maker electronics
https://www.adafruit.com/blog/feed/ maker electronics
https://www.cnx-software.com/feed/ maker electronics

# --- PHOTOGRAPHY ---
https://petapixel.com/feed/ photography
https://www.dpreview.com/feeds/news.xml photography

# --- SPACE ---
https://www.nasa.gov/rss/dyn/breaking_news.rss space
https://www.space.com/feeds/all space

# --- SECURITY ---
https://krebsonsecurity.com/feed/ security
https://www.schneier.com/feed/atom/ security


------------------------------------------------------------
NEWSBOAT CONFIGURATION
------------------------------------------------------------

The Nice Layer creates:

~/.config/newsboat/config

with the following configuration:

# High-contrast Newsboat configuration

color background        white black
color listnormal        white black
color listnormal_unread yellow black bold
color listfocus         black white bold
color listfocus_unread  black yellow bold

# Top information bar
color info              black white bold

# Bottom command/help bar
color hint-key          black white bold
color hint-description  black white
color hint-separator    black white bold

# Open full web articles in terminal using w3m
browser "w3m %u"


------------------------------------------------------------
START NEWSBOAT
------------------------------------------------------------

From the normal Linux command prompt:

newsboat

Newsboat opens the feed list.

Press:

R

to fetch/refresh all RSS feeds.

To leave Newsboat:

q

Press q repeatedly if necessary to move backward through an article/feed
and eventually exit Newsboat to the Linux prompt.


------------------------------------------------------------
BASIC NEWSBOAT CONTROLS
------------------------------------------------------------

↑ / ↓ or j / k    Move up/down
Enter             Open selected feed/article
q                 Back one level / quit
R                 Refresh ALL feeds
r                 Refresh selected feed
n                 Next unread article
p                 Previous unread article
Space             Page down
b                 Page up
u                 Toggle read/unread
/                 Search
o                 Open FULL webpage in w3m


NORMAL WORKFLOW:

Linux terminal
    |
  newsboat
    |
    v
FEED LIST
    |
  Enter
    v
ARTICLE LIST
    |
  Enter
    v
RSS ARTICLE
    |
    o
    v
FULL WEB ARTICLE IN w3m


------------------------------------------------------------
w3m — TERMINAL WEB BROWSER
------------------------------------------------------------

Newsboat can only display the content supplied by the RSS feed.

If the feed contains only a summary, press:

o

Newsboat opens the actual article webpage in w3m.

This stays entirely inside the terminal — no graphical desktop or graphical
web browser is required.


Basic w3m controls:

↑ / ↓              Scroll / move
Enter              Follow selected link
Space              Page down
b                  Page up
B                  Previous webpage
q                  Quit w3m and return to Newsboat


w3m can also browse websites directly from Linux:

w3m https://www.bbc.com


w3m works especially well with:

- News articles
- Blogs
- Documentation
- Wikipedia
- Forums
- Text-heavy websites

Sites heavily dependent on JavaScript, video, complex web apps, or some
login/paywall systems may not work correctly.


------------------------------------------------------------
NEWSBOAT / w3m VALIDATION
------------------------------------------------------------

Nice Layer installation and generated configuration were tested on
pi3-dev-1.

Result:

PASS

The following completed successfully:

sudo bash extras/raspi-nice-setup_v5.sh

The script confirmed that Newsboat and w3m were installed and generated:

~/.config/newsboat/urls
~/.config/newsboat/config

Feed/config parsing and RSS reload were then tested with:

newsboat -x reload

The command returned cleanly with no errors.

The Newsboat + w3m portion of extras/raspi-nice-setup_v5.sh is therefore
PROVEN on pi3-dev-1.

## Optional Fallback Wi-Fi Hotspot

For Raspberry Pis that may be used away from their normal saved Wi-Fi networks, an optional fallback hotspot can provide a direct SSH recovery path.

This feature is **not part of the core Raspberry Pi bootstrap** and should only be installed on Pis where portable/off-network access is useful.

### Installer

```text
extras/raspi-fallback-hotspot_v1.sh
```

The installer is standalone and optional.

> **Status:** The underlying fallback-hotspot mechanism has been proven on `pi3-dev-1`, including a real off-network/road test. The standalone `raspi-fallback-hotspot_v1.sh` installer itself is **not yet proven** and must be tested from scratch on a clean Pi before being promoted to proven status.

### Behaviour

On boot, NetworkManager is allowed to connect normally to any saved infrastructure Wi-Fi network.

```text
BOOT
  |
  +-- NetworkManager starts
  |
  +-- Wait approximately 30 seconds
  |
  +-- Infrastructure Wi-Fi connected?
        |
        +-- YES --> Leave connection alone
        |
        +-- NO  --> Start fallback hotspot
```

Once the fallback hotspot starts, it remains active until the Pi is rebooted or another NetworkManager Wi-Fi profile is manually activated.

There is intentionally no background loop periodically attempting to replace the hotspot.

### Hotspot Name

The hotspot SSID is automatically derived from the Raspberry Pi hostname.

Examples:

```text
Hostname: pi3-dev-1
SSID:     pi3-dev-1

Hostname: pi3-dev-2
SSID:     pi3-dev-2
```

The fallback hotspot is intentionally configured as an **open Wi-Fi network with no password**. It is intended as a local recovery mechanism for devices under physical control.

### Recovery

If the Pi is started somewhere none of its saved Wi-Fi networks are available:

1. Power on the Pi.
2. Wait approximately 30 seconds after networking starts.
3. Look for a Wi-Fi network matching the Pi hostname.
4. Join that network.
5. SSH using the Pi's `.local` hostname.

Example:

```bash
ssh peter@pi3-dev-1.local
```

There is no need to know or remember the hotspot's IP address.

NetworkManager's `ipv4.method shared` provides addressing/DHCP for clients connected to the hotspot.

### Returning to Normal Wi-Fi

A saved NetworkManager Wi-Fi connection can be activated manually.

Example:

```bash
sudo nmcli connection up "virus"
```

The hotspot connection will drop and the Pi will return to the selected infrastructure Wi-Fi network.

### Installation

Install directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/Peter-Langille/pi-bootstrap/main/extras/raspi-fallback-hotspot_v1.sh | sudo bash

From the `pi-bootstrap` repository:

```bash
sudo bash extras/raspi-fallback-hotspot_v1.sh
```

The installer creates/configures:

```text
NetworkManager profile:
    fallback-hotspot

/usr/local/sbin/fallback-hotspot.sh

/etc/systemd/system/fallback-hotspot.service
```

The systemd service is enabled for future boots but is not intended to disrupt the current working Wi-Fi connection during installation.

### Requirements

The target Pi requires:

```text
NetworkManager / nmcli
Wi-Fi hardware supporting AP mode
wlan0
avahi-daemon
SSH server
```

Avahi provides the convenient:

```text
<hostname>.local
```

address used for SSH recovery.

### Proven Test — pi3-dev-1

The fallback mechanism was manually built and tested on:

```text
Device:  Raspberry Pi 3 A+
Hostname: pi3-dev-1
OS:      Raspberry Pi OS / Debian 13 Trixie
Wi-Fi:   single wlan0 interface
```

The following were proven:

```text
Manual fallback-hotspot activation       PASS
Open hotspot SSID visible                PASS
Client association                       PASS
NetworkManager shared DHCP/addressing    PASS
Avahi / hostname.local resolution        PASS
SSH through fallback hotspot             PASS
Manual return to normal Wi-Fi            PASS
Normal-Wi-Fi reboot path                 PASS
Real off-network/road fallback boot      PASS
```

During the real road test, `pi3-dev-1` was booted without its normal saved Wi-Fi network available. The fallback hotspot appeared and SSH access through:

```bash
ssh peter@pi3-dev-1.local
```

was successfully established.

### Installer Proof Status

The mechanism is proven, but the standalone installer is intentionally tracked separately:

```text
raspi-fallback-hotspot_v1.sh

Installer-from-clean-system proof: NOT YET PROVEN
```

Planned proof target:

```text
pi3-dev-2
```

The installer should not be marked proven until it successfully creates the complete fallback setup on a Pi that did not previously contain the manually configured hotspot profile, fallback script, or systemd service.

## Optional OpenAI Codex CLI

For Raspberry Pis used as lightweight development or administration systems, the OpenAI Codex CLI provides direct ChatGPT/Codex access from the terminal without requiring a graphical desktop or web browser.

This feature is **not part of the core Raspberry Pi bootstrap**. It is an optional user-level installation.

### Installer

```text
extras/raspi-codex-setup_v1.sh
```

The wrapper is intentionally small.

It does **not** duplicate or maintain OpenAI's Codex installation logic. Instead, it prepares the Raspberry Pi environment and then delegates the actual Codex installation to OpenAI's current official installer.

> **Status:** Codex itself has been successfully installed and tested on `pi3-dev-1`, including ChatGPT authentication and local command execution. The standalone `raspi-codex-setup_v1.sh` wrapper is **not yet proven from a clean system** and should remain unproven until tested on a clean Raspberry Pi.

### Why the Wrapper Exists

On `pi3-dev-1`, the normal Codex installation initially failed while extracting the standalone ARM64 package.

The cause was the Raspberry Pi `/tmp` configuration:

```text
/tmp = RAM-backed tmpfs
available size ≈ 208 MB
```

The Codex release archive was approximately 88 MB compressed, but extraction required more space than the `/tmp` tmpfs could provide.

The result was a failed extraction when `/tmp` reached 100% usage.

The Pi itself had ample SD-card storage available.

The solution was to force temporary installation files onto the normal disk-backed home filesystem.

The wrapper creates:

```text
$HOME/tmp/codex-install
```

and exports:

```bash
TMPDIR="$HOME/tmp/codex-install"
```

before launching the official OpenAI installer.

This causes the upstream installer's temporary working files to use disk-backed storage instead of the small RAM-backed `/tmp`.

### Installation

Install directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/Peter-Langille/pi-bootstrap/main/extras/raspi-codex-setup_v1.sh | bash
```

**Do not use `sudo`.**

Codex is installed as a user-level application and should be installed by the normal Linux user.

From the `pi-bootstrap` repository:

```bash
bash extras/raspi-codex-setup_v1.sh
```

### Requirements

The wrapper currently requires:

```text
ARM64 / aarch64 Raspberry Pi
curl
Internet access
Normal non-root user
```

The script intentionally aborts if run as root.

### Installation Architecture

The wrapper downloads and executes OpenAI's current official installer:

```text
https://raw.githubusercontent.com/openai/codex/main/scripts/install/install.sh
```

OpenAI's installer remains responsible for:

```text
Codex release selection
ARM64 package selection
Package download
SHA-256 verification
Standalone package layout
codex-code-mode-host
ripgrep helper
bundled bubblewrap
Codex executable installation
```

The `pi-bootstrap` wrapper is responsible only for the Raspberry Pi-specific installation environment, particularly avoiding the small RAM-backed `/tmp`.

This separation is intentional so the repository does not freeze or duplicate OpenAI's installer implementation as Codex evolves.

### Installed Location

The user-facing Codex command is installed at:

```text
~/.local/bin/codex
```

The standalone Codex package is maintained beneath:

```text
~/.codex/packages/standalone/
```

The standalone package contains supporting components required by Codex in addition to the main executable.

Do **not** replace the standalone installation with only a copied `codex` binary. Testing demonstrated that a single-binary installation can start the Codex interface but leaves required helper components such as `codex-code-mode-host` unavailable.

### First Launch

Start Codex:

```bash
codex
```

On first launch, sign in using the normal ChatGPT account authentication flow.

Device-code authentication may be offered.

If device-code authorization is disabled for the ChatGPT account, it must first be enabled in the ChatGPT security settings before that authentication method can complete.

Successful authentication is stored in the user's Codex configuration and normally survives Codex upgrades/reinstallation.

### Permissions

The tested configuration on `pi3-dev-1` uses:

```text
Workspace (Ask for approval)
```

This allows Codex to work inside the current workspace while requesting approval for operations outside the permitted scope.

Permission level can be changed later from inside Codex if required.

### Bubblewrap

On `pi3-dev-1`, Codex reports that the system `bubblewrap` executable is not installed.

This is non-fatal.

The official standalone Codex package includes its own bundled `bubblewrap`, and Codex successfully used the bundled version during testing.

Installing a separate system `bubblewrap` package is therefore not currently required for this setup.

### Proven Test — pi3-dev-1

Codex was manually installed and tested on:

```text
Device:       Raspberry Pi 3 A+
Hostname:     pi3-dev-1
RAM:          512 MB
OS:           Raspberry Pi OS / Debian 13 Trixie
Architecture: aarch64
Codex tested: 0.154.0
```

The following were proven:

```text
Official ARM64 standalone package installation     PASS
ChatGPT account authentication                     PASS
Codex terminal UI                                  PASS
GPT-5.6 Sol session                                PASS
codex-code-mode-host                               PASS
Local read-only command execution                  PASS
Bundled bubblewrap operation                       PASS
Disk-backed TMPDIR workaround                      PASS
```

A local command execution test successfully ran:

```bash
uname -a
free -h
```

through Codex without modifying the system.

### Important Installation Finding

A manual installation containing only:

```text
codex
```

was **not sufficient**.

Although the Codex interface launched, command execution failed because:

```text
codex-code-mode-host
```

was missing.

The proper OpenAI standalone installation includes the required supporting package structure.

For this reason, `raspi-codex-setup_v1.sh` always delegates package installation to OpenAI's official installer rather than manually downloading or copying the Codex binary.

### Wrapper Proof Status

The underlying Codex installation procedure and Raspberry Pi `/tmp` workaround are proven on `pi3-dev-1`.

The new standalone wrapper is intentionally tracked separately:

```text
raspi-codex-setup_v1.sh

Syntax validation:                 PASS
Manual procedure represented:      PASS
Installer-from-clean-system proof: NOT YET PROVEN
```

A run on the existing `pi3-dev-1` would only prove an upgrade/reinstallation path because Codex is already installed and authenticated there.

The wrapper should not be marked **PROVEN** until it successfully installs Codex on a clean ARM64 Raspberry Pi that does not already contain the Codex standalone package.

### Design Goal

The Codex wrapper follows the same infrastructure philosophy as the rest of this repository:

```text
Reflash Pi
    |
Run bootstrap
    |
Install optional Codex wrapper
    |
Sign in to ChatGPT
    |
Continue working from the terminal
```

The Raspberry Pi-specific workaround remains under our control while OpenAI remains responsible for maintaining the Codex installer and package internals.
