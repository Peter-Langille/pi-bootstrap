#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# raspi-bootstrap.sh
# One-shot Raspberry Pi OS Lite bootstrap (NO OPTIONS)
#
# Installs:
# - git, nvim, tmux, htop, jq, rg, fzf, etc
# - docker engine + compose plugin
# - tailscale (installed, but NOT auto-logged-in)
# - Miniforge (conda-forge) to /opt/conda
# - JupyterLab + core data libs via conda
#
# Intended target:
# - Raspberry Pi OS (Debian-based), arm64 preferred
#
# Safety:
# - Will not copy private SSH keys
# - Will not auto-join Tailscale
# - Will not format/mount NVMe
# ============================================================

log() { echo -e "\n[BOOTSTRAP] $*\n"; }
die() { echo -e "\n[BOOTSTRAP][ERROR] $*\n" >&2; exit 1; }

require_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run as root: sudo bash $0"
  fi
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  else
    die "Cannot read /etc/os-release"
  fi

  if [[ "${ID_LIKE:-}" != *"debian"* && "${ID:-}" != "debian" && "${ID:-}" != "raspbian" ]]; then
    die "This script targets Debian/Raspberry Pi OS. Detected: ID=${ID:-?}, ID_LIKE=${ID_LIKE:-?}"
  fi
}

detect_arch() {
  ARCH="$(uname -m)"
  case "$ARCH" in
    aarch64) MINIFORGE_ARCH="aarch64" ;;
    armv7l|armv6l)
      die "Detected 32-bit ARM ($ARCH). This bootstrap expects 64-bit Raspberry Pi OS (arm64). Re-flash 64-bit Lite."
      ;;
    x86_64)
      die "Detected x86_64. This script is meant to run ON the Pi (arm64)."
      ;;
    *)
      die "Unsupported architecture: $ARCH"
      ;;
  esac
}

ensure_user_context() {
  # If run via sudo, SUDO_USER is the original user. We'll configure user-level items for them.
  if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
    die "Please run with sudo from a normal user account (so we can configure that user). Example: sudo bash raspi-bootstrap.sh"
  fi
  TARGET_USER="${SUDO_USER}"
  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
  [[ -n "${TARGET_HOME}" && -d "${TARGET_HOME}" ]] || die "Could not resolve home dir for user: ${TARGET_USER}"
}

apt_update_upgrade() {
  log "Updating apt indexes and upgrading base system..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
}

apt_install_basics() {
  log "Installing baseline packages..."
  export DEBIAN_FRONTEND=noninteractive

  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    openssh-server \
    neovim \
    tmux \
    htop \
    jq \
    ripgrep \
    fzf \
    tree \
    rsync \
    unzip \
    zip \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    python3 \
    python3-venv \
    python3-pip

  systemctl enable ssh >/dev/null 2>&1 || true
  systemctl start ssh  >/dev/null 2>&1 || true
}

install_docker() {
  log "Installing Docker (engine + compose plugin)..."

  if command -v docker >/dev/null 2>&1; then
    log "Docker already present. Skipping install."
  else
    # Simple + reliable for Raspberry Pi OS:
    # https://get.docker.com
    curl -fsSL https://get.docker.com | sh
  fi

  # Ensure service enabled + running
  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker  >/dev/null 2>&1 || true

  # Add user to docker group
  if id -nG "${TARGET_USER}" | grep -qw docker; then
    log "User '${TARGET_USER}' is already in docker group."
  else
    log "Adding user '${TARGET_USER}' to docker group..."
    usermod -aG docker "${TARGET_USER}"
  fi
}

install_tailscale() {
  log "Installing Tailscale (not logging in)..."
  if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale already present. Skipping install."
    return
  fi

  curl -fsSL https://tailscale.com/install.sh | sh

  systemctl enable tailscaled >/dev/null 2>&1 || true
  systemctl start tailscaled  >/dev/null 2>&1 || true

  log "NOTE: Tailscale installed. You must run 'sudo tailscale up' manually to authenticate."
}

install_miniforge() {
  log "Installing Miniforge to /opt/conda ..."
  if [[ -x /opt/conda/bin/conda ]]; then
    log "Miniforge already present at /opt/conda. Skipping installer."
  else
    TMPDIR="$(mktemp -d)"
    INSTALLER="${TMPDIR}/Miniforge3.sh"
    URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${MINIFORGE_ARCH}.sh"

    log "Downloading: ${URL}"
    curl -fsSL "${URL}" -o "${INSTALLER}"

    bash "${INSTALLER}" -b -p /opt/conda
    rm -rf "${TMPDIR}"
  fi

  # Make conda available system-wide
  log "Configuring system-wide conda PATH..."
  cat >/etc/profile.d/conda.sh <<'EOF'
# Added by raspi-bootstrap
if [ -d /opt/conda/bin ]; then
  export PATH="/opt/conda/bin:$PATH"
fi
EOF

  ln -sf /opt/conda/bin/conda /usr/local/bin/conda || true
}

conda_install_dev_stack() {
  log "Installing JupyterLab + core Python data stack via conda (in base env)..."
  if [[ ! -x /opt/conda/bin/conda ]]; then
    die "conda not found at /opt/conda/bin/conda"
  fi

  # Ensure conda can run non-interactively
  /opt/conda/bin/conda config --system --set auto_activate_base false >/dev/null 2>&1 || true

  # Update base tooling
  /opt/conda/bin/conda update -y -n base conda || true

  # Install the stuff you want "always there"
  /opt/conda/bin/conda install -y -n base \
    jupyterlab \
    ipykernel \
    numpy \
    pandas \
    pyarrow \
    requests \
    lxml

  # Register an IPython kernel name that’s obvious
  # (jupyter will still work without this, but it’s nice)
  su - "${TARGET_USER}" -c "/opt/conda/bin/python -m ipykernel install --user --name conda-base --display-name 'Python (conda-base)'" >/dev/null 2>&1 || true
}

set_quality_of_life() {
  log "Applying a few quality-of-life defaults..."
  # Default editor
  cat >/etc/profile.d/editor.sh <<'EOF'
# Added by raspi-bootstrap
export EDITOR=nvim
export VISUAL=nvim
EOF

  # Create a simple ~/bin for the user (harmless, optional utility)
  su - "${TARGET_USER}" -c "mkdir -p '${TARGET_HOME}/bin'"

  # Show a friendly post-login hint (minimal, not spammy)
  MOTD_FILE="/etc/motd"
  if ! grep -q "raspi-bootstrap" "${MOTD_FILE}" 2>/dev/null; then
    cat >>"${MOTD_FILE}" <<'EOF'

[raspi-bootstrap]
- Docker installed. If 'docker' permission denied, log out/in or reboot.
- Tailscale installed. Authenticate with: sudo tailscale up
- Conda installed at /opt/conda. Try: conda --version
- JupyterLab available. Start with: jupyter lab --ip=0.0.0.0 --no-browser
EOF
  fi
}

final_checks() {
  log "Final checks (best effort)..."

  echo "OS: $(lsb_release -ds 2>/dev/null || true)"
  echo "ARCH: $(uname -m)"
  echo "git: $(git --version 2>/dev/null || echo missing)"
  echo "nvim: $(nvim --version 2>/dev/null | head -n 1 || echo missing)"
  echo "docker: $(docker --version 2>/dev/null || echo missing)"
  echo "tailscale: $(tailscale version 2>/dev/null || echo missing)"
  echo "conda: $(conda --version 2>/dev/null || echo missing)"
  echo "jupyter: $(jupyter lab --version 2>/dev/null || echo missing)"

  log "Bootstrap complete."
  echo "NEXT:"
  echo "  1) Reboot: sudo reboot"
  echo "  2) After reboot: docker run --rm hello-world"
  echo "  3) Authenticate Tailscale: sudo tailscale up"
}

main() {
  require_sudo
  detect_os
  detect_arch
  ensure_user_context

  apt_update_upgrade
  apt_install_basics
  install_docker
  install_tailscale
  install_miniforge
  conda_install_dev_stack
  set_quality_of_life
  final_checks
}

main "$@"

