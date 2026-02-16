#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# raspi-nice-setup_v1.sh
# Optional "nice layer" for Pi dev boxes.
#
# Safe to re-run. Touches user-space only.
#
# What it does:
# - Installs Starship prompt to ~/.local/bin
# - Writes ~/.config/starship.toml (backs up existing)
# - Enables Starship in Bash (adds a guarded block to ~/.bashrc)
# - Ensures Conda doesn't double-modify PS1 (changeps1 False)
# - Installs FiraCode Nerd Font to ~/.local/share/fonts (best effort)
# - Sets global gitignore + git config core.excludesfile
# - Installs a baseline ~/.tmux.conf
# - Adds a small alias/shortcut pack via ~/.bashrc.d/pi-nice.sh
#
# Requirements (from bootstrap):
# - curl, git, jq, tar, gzip/xz, fontconfig (fc-cache), tmux
# - conda at /opt/conda (optional but recommended)
# ============================================================

log() { echo -e "\n[NICE] $*\n"; }

# ---------- user context ----------
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  TARGET_USER="${SUDO_USER}"
else
  TARGET_USER="$(id -un)"
fi
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
[[ -n "${TARGET_HOME}" && -d "${TARGET_HOME}" ]] || { echo "[NICE][ERROR] Cannot resolve home for ${TARGET_USER}"; exit 1; }

as_user() { sudo -u "${TARGET_USER}" -H bash -lc "$*"; }

# ---------- paths ----------
LOCAL_BIN="${TARGET_HOME}/.local/bin"
CONFIG_DIR="${TARGET_HOME}/.config"
BASHRC="${TARGET_HOME}/.bashrc"
BASHRC_D="${TARGET_HOME}/.bashrc.d"
STARSHIP_TOML="${CONFIG_DIR}/starship.toml"
GITIGNORE_GLOBAL="${CONFIG_DIR}/git/ignore"
TMUX_CONF="${TARGET_HOME}/.tmux.conf"

mkdir -p "${LOCAL_BIN}" "${CONFIG_DIR}" "${BASHRC_D}" "${CONFIG_DIR}/git"

# ============================================================
# 1) STARSHIP INSTALL
# ============================================================
install_starship() {
  if as_user "command -v starship >/dev/null 2>&1"; then
    log "Starship already installed. Skipping."
    return
  fi

  log "Installing Starship to ${LOCAL_BIN} ..."
  # Starship FAQ documents install.sh with -b for install dir. :contentReference[oaicite:4]{index=4}
  as_user "curl -sS https://starship.rs/install.sh | sh -s -- -b '${LOCAL_BIN}' -y"
}

# ============================================================
# 2) STARSHIP CONFIG (includes conda module)
# ============================================================
write_starship_toml() {
  log "Writing ${STARSHIP_TOML} (backup if exists) ..."
  as_user "mkdir -p '${CONFIG_DIR}'"

  if as_user "[[ -f '${STARSHIP_TOML}' ]]"; then
    TS="$(date +%Y%m%d_%H%M%S)"
    as_user "cp -a '${STARSHIP_TOML}' '${STARSHIP_TOML}.bak_${TS}'"
  fi

  cat > /tmp/starship.toml <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'

add_newline = false
command_timeout = 750

# Simple, readable, nerd-font friendly prompt.
# Includes Conda env in prompt (via $conda).
format = """
$directory\
$git_branch\
$git_status\
$conda\
$character\
"""

[directory]
truncation_length = 4
truncate_to_repo = true

[git_branch]
symbol = " "
format = "[$symbol$branch]($style) "
style = "bold purple"

[git_status]
format = "[$all_status$ahead_behind]($style) "
style = "bold yellow"

# Conda module shows current environment when CONDA_DEFAULT_ENV is set. :contentReference[oaicite:5]{index=5}
[conda]
symbol = " "
format = "[$symbol$environment]($style) "
style = "bold green"
ignore_base = false

[character]
success_symbol = "[➜](bold green) "
error_symbol = "[➜](bold red) "
EOF

  as_user "install -m 0644 /tmp/starship.toml '${STARSHIP_TOML}'"
  rm -f /tmp/starship.toml
}

# ============================================================
# 3) ENABLE STARSHIP IN BASH
# ============================================================
enable_starship_bash() {
  log "Enabling Starship for Bash via guarded ~/.bashrc block ..."
  # Ensure ~/.local/bin is on PATH
  if ! grep -q 'export PATH="\$HOME/.local/bin:\$PATH"' "${BASHRC}" 2>/dev/null; then
    cat >> "${BASHRC}" <<'EOF'

# --- pi-nice: ensure user local bin on PATH ---
export PATH="$HOME/.local/bin:$PATH"
EOF
  fi

  # Create a sourced file for aliases/settings
  cat > /tmp/pi-nice.sh <<'EOF'
# pi-nice user shortcuts (safe to edit)
alias ll='ls -lah'
alias gs='git status'
alias gl='git log --oneline --decorate -20'
alias gd='git diff'
alias dc='docker compose'
EOF
  as_user "install -m 0644 /tmp/pi-nice.sh '${BASHRC_D}/pi-nice.sh'"
  rm -f /tmp/pi-nice.sh

  # Ensure ~/.bashrc sources ~/.bashrc.d/*.sh
  if ! grep -q 'pi-nice: source bashrc.d' "${BASHRC}" 2>/dev/null; then
    cat >> "${BASHRC}" <<'EOF'

# --- pi-nice: source bashrc.d (if present) ---
if [ -d "$HOME/.bashrc.d" ]; then
  for f in "$HOME/.bashrc.d/"*.sh; do
    [ -r "$f" ] && . "$f"
  done
fi
EOF
  fi

  # Enable starship init (guarded; only if installed)
  if ! grep -q 'pi-nice: starship init' "${BASHRC}" 2>/dev/null; then
    cat >> "${BASHRC}" <<'EOF'

# --- pi-nice: starship init ---
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
EOF
  fi
}

# ============================================================
# 4) CONDA PROMPT BEHAVIOUR (avoid double prompt)
# ============================================================
conda_prompt_sanity() {
  if [[ -x /opt/conda/bin/conda ]]; then
    log "Setting conda changeps1 False (prevents conda from modifying PS1)..."
    # Starship conda docs recommend disabling conda's own prompt modifier. :contentReference[oaicite:6]{index=6}
    /opt/conda/bin/conda config --set changeps1 False || true
  else
    log "Conda not found at /opt/conda/bin/conda (skipping conda prompt setting)."
  fi
}

# ============================================================
# 5) FiraCode Nerd Font (best effort)
# ============================================================
install_firacode_nerd_font() {
  log "Installing FiraCode Nerd Font (best effort) ..."
  # This is only useful if you have a GUI terminal that can select the font.
  # On headless boxes, it's harmless to install; you may later use it with a desktop.
  FONT_DIR="${TARGET_HOME}/.local/share/fonts/FiraCodeNerdFont"
  as_user "mkdir -p '${FONT_DIR}'"

  # Use GitHub API to fetch latest Nerd Fonts release tag and download the asset.
  # Nerd Fonts releases include FiraCode.tar.xz. :contentReference[oaicite:7]{index=7}
  TAG="$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r .tag_name)"
  [[ -n "${TAG}" && "${TAG}" != "null" ]] || { log "Could not resolve Nerd Fonts latest tag; skipping font install."; return; }

  URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${TAG}/FiraCode.tar.xz"
  TMP="$(mktemp -d)"
  ARCHIVE="${TMP}/FiraCode.tar.xz"

  log "Downloading ${URL}"
  as_user "curl -fsSL '${URL}' -o '${ARCHIVE}'"

  # Extract TTF/OTF files into user font dir
  as_user "tar -xf '${ARCHIVE}' -C '${FONT_DIR}'"
  rm -rf "${TMP}"

  # Refresh font cache if available
  if as_user "command -v fc-cache >/dev/null 2>&1"; then
    as_user "fc-cache -f '${TARGET_HOME}/.local/share/fonts' >/dev/null 2>&1 || true"
  fi
}

# ============================================================
# 6) GLOBAL GITIGNORE
# ============================================================
write_global_gitignore() {
  log "Writing global gitignore to ${GITIGNORE_GLOBAL} ..."
  as_user "mkdir -p '${CONFIG_DIR}/git'"

  cat > /tmp/gitignore_global <<'EOF'
# OS junk
.DS_Store
Thumbs.db

# Editors
*.swp
*.swo
*~
.vscode/
.idea/

# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
.venv/
venv/
.env

# Jupyter
.ipynb_checkpoints/

# Logs
*.log

# Local data / caches (project-specific; adjust as needed)
data/
cache/
EOF

  as_user "install -m 0644 /tmp/gitignore_global '${GITIGNORE_GLOBAL}'"
  rm -f /tmp/gitignore_global

  log "Configuring git to use the global ignore..."
  as_user "git config --global core.excludesfile '${GITIGNORE_GLOBAL}'"
}

# ============================================================
# 7) TMUX CONF
# ============================================================
write_tmux_conf() {
  log "Writing ${TMUX_CONF} (backup if exists) ..."
  if as_user "[[ -f '${TMUX_CONF}' ]]"; then
    TS="$(date +%Y%m%d_%H%M%S)"
    as_user "cp -a '${TMUX_CONF}' '${TMUX_CONF}.bak_${TS}'"
  fi

  cat > /tmp/tmux.conf <<'EOF'
# Basic tmux defaults (safe, minimal)
set -g mouse on
set -g history-limit 20000

# Use Ctrl-a as prefix (optional; comment out if you prefer default Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Split shortcuts
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Vim-like pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Faster escape
set -sg escape-time 10
EOF

  as_user "install -m 0644 /tmp/tmux.conf '${TMUX_CONF}'"
  rm -f /tmp/tmux.conf
}

main() {
  install_starship
  write_starship_toml
  enable_starship_bash
  conda_prompt_sanity
  install_firacode_nerd_font
  write_global_gitignore
  write_tmux_conf

  log "Nice setup complete."
  echo "NEXT:"
  echo "  1) Start a new shell session (log out/in) OR run: source ~/.bashrc"
  echo "  2) Verify: starship --version"
  echo "  3) Verify gitignore: git config --global core.excludesfile"
}

main "$@"

