#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# raspi-bootstrap_v4_pi3_mllite_trixie.sh
#
# Raspberry Pi 3 A+ / low-memory ARM64 bootstrap
# Debian 13 / Raspberry Pi OS Trixie
#
# Design:
# - Creates and persists a 2 GB disk swapfile early
# - Leaves Raspberry Pi zram enabled and untouched
# - Safely validates any existing /swapfile before using it
# - Installs Miniforge to /opt/conda
# - Keeps Conda base clean
# - DOES NOT perform a large dependency solve on the Pi
# - Creates dedicated pi3-ml environment from explicit ARM64 lock
# - Registers pi3-ml as a Jupyter kernel
#
# Required repo file:
#
#   locks/pi3-ml-linux-aarch64-explicit.txt
#
# Run:
#
#   sudo bash raspi-bootstrap_v4_pi3_mllite_trixie.sh
#
# ============================================================


log() {
  echo -e "\n[BOOTSTRAP] $*\n"
}


die() {
  echo -e "\n[BOOTSTRAP][ERROR] $*\n" >&2
  exit 1
}


require_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run as root via sudo: sudo bash $0"
  fi
}


detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  else
    die "Cannot read /etc/os-release"
  fi

  if [[ "${ID_LIKE:-}" != *"debian"* &&
        "${ID:-}" != "debian" &&
        "${ID:-}" != "raspbian" ]]; then

    die "This script targets Debian/Raspberry Pi OS. Detected: ID=${ID:-?}, ID_LIKE=${ID_LIKE:-?}"
  fi
}


detect_arch() {
  ARCH="$(uname -m)"

  case "${ARCH}" in
    aarch64)
      MINIFORGE_ARCH="aarch64"
      ;;

    armv7l|armv6l)
      die "Detected 32-bit ARM (${ARCH}). This bootstrap requires a 64-bit OS."
      ;;

    x86_64)
      die "Detected x86_64. This script is intended for Raspberry Pi ARM64."
      ;;

    *)
      die "Unsupported architecture: ${ARCH}"
      ;;
  esac
}


ensure_user_context() {
  if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
    die "Run with sudo from a normal user account. Example: sudo bash $0"
  fi

  TARGET_USER="${SUDO_USER}"
  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

  [[ -n "${TARGET_HOME}" && -d "${TARGET_HOME}" ]] ||
    die "Could not resolve home directory for user: ${TARGET_USER}"
}


resolve_paths() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  LOCK_FILE="${SCRIPT_DIR}/locks/pi3-ml-linux-aarch64-explicit.txt"
  PI3_ENV="/opt/conda/envs/pi3-ml"

  [[ -f "${LOCK_FILE}" ]] ||
    die "Required explicit lock file not found: ${LOCK_FILE}"
}


swap_is_active() {
  swapon --show=NAME --noheadings 2>/dev/null |
    awk '{$1=$1};1' |
    grep -Fxq "/swapfile"
}


configure_swap() {
  log "Configuring persistent 2 GB disk swap..."

  SWAPFILE="/swapfile"

  if [[ -e "${SWAPFILE}" ]]; then

    log "${SWAPFILE} already exists. Validating it before use..."

    if swap_is_active; then

      log "${SWAPFILE} is already active and valid."

    else

      SWAP_TYPE="$(blkid -p -s TYPE -o value "${SWAPFILE}" 2>/dev/null || true)"

      if [[ "${SWAP_TYPE}" != "swap" ]]; then
        die "${SWAPFILE} exists but is not a valid swap file. Refusing to overwrite it."
      fi

      log "Existing ${SWAPFILE} contains a valid swap signature."
    fi

    chmod 600 "${SWAPFILE}"

  else

    log "Creating new 2 GB ${SWAPFILE}..."

    fallocate -l 2G "${SWAPFILE}"
    chmod 600 "${SWAPFILE}"
    mkswap "${SWAPFILE}"
  fi

  if ! grep -Eq '^[[:space:]]*/swapfile[[:space:]]' /etc/fstab; then

    log "Adding persistent swap entry to /etc/fstab..."

    echo '/swapfile none swap sw 0 0' >> /etc/fstab

  else

    log "/swapfile already present in /etc/fstab."
  fi

  if swap_is_active; then

    log "${SWAPFILE} is already enabled."

  else

    log "Enabling ${SWAPFILE}..."

    swapon "${SWAPFILE}"
  fi

  log "Current swap configuration:"

  swapon --show
}


apt_update_upgrade() {
  log "Updating apt indexes and upgrading base system..."

  export DEBIAN_FRONTEND=noninteractive
  export DEBIAN_PRIORITY=critical

  apt-get update -y

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
  log "Installing Docker engine + compose plugin..."

  if command -v docker >/dev/null 2>&1; then

    log "Docker already present. Skipping installer."

  else

    curl -fsSL https://get.docker.com | sh
  fi

  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker  >/dev/null 2>&1 || true

  if id -nG "${TARGET_USER}" | grep -qw docker; then

    log "User '${TARGET_USER}' already belongs to docker group."

  else

    log "Adding '${TARGET_USER}' to docker group..."

    usermod -aG docker "${TARGET_USER}"
  fi
}


install_tailscale() {
  log "Installing Tailscale..."

  if command -v tailscale >/dev/null 2>&1; then

    log "Tailscale already present. Skipping installer."

  else

    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  systemctl enable tailscaled >/dev/null 2>&1 || true
  systemctl start tailscaled  >/dev/null 2>&1 || true

  log "Tailscale installation complete. Authentication remains manual."
}


install_miniforge() {
  log "Installing Miniforge to /opt/conda..."

  if [[ -x /opt/conda/bin/conda ]]; then

    log "Miniforge already present at /opt/conda. Skipping installer."

  else

    TMPDIR_BOOTSTRAP="$(mktemp -d)"
    INSTALLER="${TMPDIR_BOOTSTRAP}/Miniforge3.sh"

    URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${MINIFORGE_ARCH}.sh"

    log "Downloading Miniforge:"
    echo "${URL}"

    curl -fsSL "${URL}" -o "${INSTALLER}"

    bash "${INSTALLER}" -b -p /opt/conda

    rm -rf "${TMPDIR_BOOTSTRAP}"
  fi

  log "Configuring Conda PATH..."

  cat >/etc/profile.d/conda.sh <<'EOF'
# Added by raspi-bootstrap
if [ -d /opt/conda/bin ]; then
  export PATH="/opt/conda/bin:$PATH"
fi
EOF

  ln -sf /opt/conda/bin/conda /usr/local/bin/conda

  log "Disabling automatic activation of Conda base..."

  /opt/conda/bin/conda config \
    --system \
    --set auto_activate_base false
}


create_pi3_ml_environment() {
  log "Creating dedicated pi3-ml environment from explicit ARM64 lock..."

  [[ -x /opt/conda/bin/conda ]] ||
    die "Conda not found at /opt/conda/bin/conda"

  [[ -f "${LOCK_FILE}" ]] ||
    die "Explicit lock file missing: ${LOCK_FILE}"

  if [[ -x "${PI3_ENV}/bin/python" ]]; then

    log "pi3-ml environment already exists at ${PI3_ENV}. Skipping environment creation."

  else

    log "Installing exact packages from:"
    echo "${LOCK_FILE}"

    /opt/conda/bin/conda create \
      -y \
      -p "${PI3_ENV}" \
      --file "${LOCK_FILE}"
  fi

  [[ -x "${PI3_ENV}/bin/python" ]] ||
    die "pi3-ml Python was not created successfully."

  [[ -x "${PI3_ENV}/bin/jupyter" ]] ||
    die "Jupyter was not installed in pi3-ml."

  ln -sf "${PI3_ENV}/bin/jupyter" /usr/local/bin/jupyter

  if [[ -x "${PI3_ENV}/bin/jupyter-lab" ]]; then
    ln -sf "${PI3_ENV}/bin/jupyter-lab" /usr/local/bin/jupyter-lab
  fi
}


register_jupyter_kernel() {
  log "Registering pi3-ml Jupyter kernel for ${TARGET_USER}..."

  su - "${TARGET_USER}" -c \
    "${PI3_ENV}/bin/python -m ipykernel install \
      --user \
      --name pi3-ml \
      --display-name 'Python (pi3-ml)'"
}


set_quality_of_life() {
  log "Applying basic editor defaults..."

  cat >/etc/profile.d/editor.sh <<'EOF'
# Added by raspi-bootstrap
export EDITOR=nvim
export VISUAL=nvim
EOF

  su - "${TARGET_USER}" -c "mkdir -p '${TARGET_HOME}/bin'"
}


validate_ml_stack() {
  log "Validating pi3-ml environment..."

  "${PI3_ENV}/bin/python" -c \
    "import numpy, pandas, pyarrow, requests, lxml, matplotlib, yaml, sklearn, xgboost, lightgbm, joblib, onnxruntime; print('ML/data stack PASS')"

  "${PI3_ENV}/bin/python" --version

  "${PI3_ENV}/bin/jupyter" lab --version
}


final_checks() {
  log "Final checks..."

  echo "OS: $(lsb_release -ds 2>/dev/null || true)"
  echo "ARCH: $(uname -m)"
  echo

  echo "git: $(git --version 2>/dev/null || echo missing)"
  echo "nvim: $(nvim --version 2>/dev/null | head -n 1 || echo missing)"
  echo "docker: $(docker --version 2>/dev/null || echo missing)"
  echo "tailscale: $(tailscale version 2>/dev/null | head -n 1 || echo missing)"
  echo "conda: $(/opt/conda/bin/conda --version 2>/dev/null || echo missing)"
  echo "pi3-ml python: $(${PI3_ENV}/bin/python --version 2>/dev/null || echo missing)"
  echo "jupyter: $(${PI3_ENV}/bin/jupyter lab --version 2>/dev/null || echo missing)"

  echo
  echo "Swap:"
  swapon --show

  echo

  log "Pi 3 bootstrap complete."

  echo "NEXT:"
  echo "  1) Reboot: sudo reboot"
  echo "  2) After reboot verify swap: swapon --show"
  echo "  3) Test Docker: docker run --rm hello-world"
  echo "  4) Authenticate Tailscale: sudo tailscale up"
  echo "  5) Verify ML environment:"
  echo "       ${PI3_ENV}/bin/python -c \"import sklearn, xgboost, lightgbm, joblib, onnxruntime; print('PASS')\""
  echo
  echo "Optional Nice Layer:"
  echo "  curl -fsSL https://raw.githubusercontent.com/Peter-Langille/pi-bootstrap/main/extras/raspi-nice-setup_v5.sh | sudo bash"
}


main() {
  require_sudo
  detect_os
  detect_arch
  ensure_user_context
  resolve_paths

  # Low-memory protection comes before apt/conda workload.
  configure_swap

  apt_update_upgrade
  apt_install_basics

  install_docker
  install_tailscale

  install_miniforge
  create_pi3_ml_environment
  register_jupyter_kernel

  set_quality_of_life

  validate_ml_stack
  final_checks
}


main "$@"
