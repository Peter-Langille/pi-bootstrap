#!/usr/bin/env bash

set -euo pipefail

log()  { echo -e "\n[CODEX] $*\n"; }
die()  { echo -e "\n[CODEX][ERROR] $*\n" >&2; exit 1; }

INSTALLER_URL="https://raw.githubusercontent.com/openai/codex/main/scripts/install/install.sh"

# ------------------------------------------------------------
# Preconditions
# ------------------------------------------------------------

[[ "${EUID}" -ne 0 ]] || die "Run this script as your normal user, not with sudo."

ARCH="$(uname -m)"

case "${ARCH}" in
  aarch64|arm64)
    ;;
  *)
    die "This setup is intended for ARM64/aarch64 Raspberry Pi systems. Detected: ${ARCH}"
    ;;
esac

command -v curl >/dev/null 2>&1 || die "curl is required."

# ------------------------------------------------------------
# Disk-backed temporary directory
# ------------------------------------------------------------

CODEX_TMP="${HOME}/tmp/codex-install"

log "Preparing disk-backed temporary directory: ${CODEX_TMP}"

mkdir -p "${CODEX_TMP}"

# Force mktemp and the upstream Codex installer away from /tmp.
# This matters on low-memory Raspberry Pis where /tmp may be a
# small RAM-backed tmpfs that cannot hold the Codex package.
export TMPDIR="${CODEX_TMP}"

# ------------------------------------------------------------
# Download current official OpenAI installer
# ------------------------------------------------------------

UPSTREAM_INSTALLER="${CODEX_TMP}/openai-codex-install.sh"

log "Downloading current official OpenAI Codex installer..."

curl -fsSL "${INSTALLER_URL}" -o "${UPSTREAM_INSTALLER}"

chmod 0700 "${UPSTREAM_INSTALLER}"

# ------------------------------------------------------------
# Hand installation over to OpenAI
# ------------------------------------------------------------

log "Running official OpenAI installer with TMPDIR=${TMPDIR}"

"${UPSTREAM_INSTALLER}"

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

CODEX_BIN="${HOME}/.local/bin/codex"

[[ -x "${CODEX_BIN}" ]] ||
  die "Installation completed but ${CODEX_BIN} was not found."

log "Installed Codex version:"

"${CODEX_BIN}" --version

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

log "Cleaning temporary installer files..."

rm -rf "${CODEX_TMP}"

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------

log "Codex CLI installation complete."

echo "Installed command:"
echo "  ${CODEX_BIN}"
echo
echo "NEXT:"
echo "  Start Codex with: codex"
echo "  Sign in with your ChatGPT account when prompted."
