#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# raspi-bootstrap_v3_mllite_trixie.sh
# One-shot Raspberry Pi OS / Debian 13 (trixie) bootstrap (NO OPTIONS)
#
# Installs:
# - Core CLI/dev tools: git, nvim, tmux, htop, jq, rg, fzf, etc
# - Docker engine + compose plugin
# - Tailscale (installed, NOT auto-logged-in)
# - Miniforge (conda-forge) to /opt/conda
# - JupyterLab + core data libs via conda base env
# - ML-lite stack for realtime transform inference:
#     scikit-learn, xgboost, lightgbm, joblib, onnxruntime
#
# Hardened for Debian 13 / Pi OS trixie:
# - Non-interactive apt upgrade (no dpkg config prompts)
# - Removed software-properties-common (not available on trixie)
# - Uses explicit /opt/conda/bin paths for conda/python/jupyter
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

  # Pi OS trixie often reports ID=debian, which is OK.
  if [[ "${ID_LIKE:-}" != *"debian"* && "${ID:-}" != "debian" && "${ID:-}" != "raspbian" ]]; then
    die "This script targets Debian/Raspberry Pi OS. Detected: ID=${ID:-?}, ID_LIKE=${ID_LIKE:-?}"
  fi
}

detect_arch() {
  ARCH="$(uname -m)"
  case "$ARCH" in
    aarch64) MINIFORGE_ARCH="aarch64" ;;
    armv7l|armv6l)
      die "Detected 32-bit ARM ($ARCH). This bootstrap expects 64-bit OS (arm64/aarch64)."
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
  if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
    die "Run with sudo from a normal user account. Example: sudo bash $0"
  fi
  TARGET_USER="${SUDO_USER}"
  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
  [[ -n "${TARGET_HOME}" && -d "${TARGET_HOME}" ]] || die "Could not resolve home dir for user: ${TARGET_USER}"
}

apt_update_upgrade() {
  log "Updating apt indexes and upgrading base system (non-interactive, keep existing configs)..."
  export DEBIAN_FRONTEND=noninteractive
  export DEBIAN_PRIORITY=critical

  apt-get update -y
  # Prevent dpkg config prompts: keep existing config when modified.
  # (force-confdef: use defaults; force-confold: keep old config if changed)
  apt-get -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    upgrade
}

apt_install_basics() {
  log "Installing baseline packages..."
  export DEBIAN_FRONTEND=noninteractive
  export DEBIAN_PRIORITY=critical

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
    curl -fsSL https://get.docker.com | sh
  fi

  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker  >/dev/null 2>&1 || true

  if id -nG "${TARGET_USER}" | grep -qw docker; then
    log "User '${TARGET_USER}' already in docker group."
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

  log "Configuring conda PATH for login shells..."
  cat >/etc/profile.d/conda.sh <<'EOF'
# Added by raspi-bootstrap
if [ -d /opt/conda/bin ]; then
  export PATH="/opt/conda/bin:$PATH"
fi
EOF

  ln -sf /opt/conda/bin/conda   /usr/local/bin/conda   || true
  ln -sf /opt/conda/bin/jupyter /usr/local/bin/jupyter || true
}

conda_install_dev_stack() {
  log "Installing JupyterLab + core Python data + ML-lite stack via conda (base env)..."
  [[ -x /opt/conda/bin/conda ]] || die "conda not found at /opt/conda/bin/conda"

  /opt/conda/bin/conda config --system --set auto_activate_base false >/dev/null 2>&1 || true
  /opt/conda/bin/conda update -y -n base conda || true

  /opt/conda/bin/conda install -y -n base \
    jupyterlab \
    ipykernel \
    numpy \
    pandas \
    pyarrow \
    requests \
    lxml \
    matplotlib \
    pyyaml \
    scikit-learn \
    xgboost \
    lightgbm \
    joblib \
    onnxruntime

  su - "${TARGET_USER}" -c "/opt/conda/bin/python -m ipykernel install --user --name conda-base --display-name 'Python (conda-base)'" >/dev/null 2>&1 || true
}

set_quality_of_life() {
  log "Applying quality-of-life defaults..."
  cat >/etc/profile.d/editor.sh <<'EOF'
# Added by raspi-bootstrap
export EDITOR=nvim
export VISUAL=nvim
EOF

  su - "${TARGET_USER}" -c "mkdir -p '${TARGET_HOME}/bin'"
}

final_checks() {
  log "Final checks (best effort)..."

  echo "OS: $(lsb_release -ds 2>/dev/null || true)"
  echo "ARCH: $(uname -m)"
  echo "git: $(git --version 2>/dev/null || echo missing)"
  echo "nvim: $(nvim --version 2>/dev/null | head -n 1 || echo missing)"
  echo "docker: $(docker --version 2>/dev/null || echo missing)"
  echo "tailscale: $(tailscale version 2>/dev/null || echo missing)"
  echo "conda: $(/opt/conda/bin/conda --version 2>/dev/null || echo missing)"
  echo "jupyter: $(/opt/conda/bin/jupyter lab --version 2>/dev/null || echo missing)"
  echo "conda-python: $(/opt/conda/bin/python --version 2>/dev/null || echo missing)"

  log "Bootstrap complete."
  echo "NEXT:"
  echo "  1) Reboot: sudo reboot"
  echo "  2) After reboot: docker run --rm hello-world"
  echo "  3) Authenticate Tailscale: sudo tailscale up"
  echo "  4) ML-lite sanity:"
  echo "       /opt/conda/bin/python -c \"import sklearn, xgboost, lightgbm, joblib\""
  echo "       /opt/conda/bin/python -c \"import onnxruntime as ort; print(ort.__version__)\""
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

