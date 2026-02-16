#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# raspi-nice-setup_v2.sh
# Optional "nice layer" for Pi dev boxes.
#
# Designed to be run as:
#   curl ... | sudo bash
#
# Key contract:
# - NEVER writes to user home as root
# - All user-home writes happen via sudo -u TARGET_USER
# - Safe to re-run; backs up existing config files it overwrites
# ============================================================

log() { echo -e "\n[NICE] $*\n"; }
die() { echo -e "\n[NICE][ERROR] $*\n" >&2; exit 1; }

require_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run as root (recommended): curl ... | sudo bash"
  fi
}

resolve_target_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="${SUDO_USER}"
  else
    die "This script must be run via sudo from a normal user (SUDO_USER not set)."
  fi

  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
  [[ -n "${TARGET_HOME}" && -d "${TARGET_HOME}" ]] || die "Cannot resolve home for ${TARGET_USER}"
}

as_user() {
  sudo -u "${TARGET_USER}" -H bash -lc "$*"
}

# Paths in the TARGET_USER home
user_path_init() {
  LOCAL_BIN="${TARGET_HOME}/.local/bin"
  CONFIG_DIR="${TARGET_HOME}/.config"
  BASHRC="${TARGET_HOME}/.bashrc"
  BASHRC_D="${TARGET_HOME}/.bashrc.d"
  STARSHIP_TOML="${CONFIG_DIR}/starship.toml"
  GITIGNORE_GLOBAL="${CONFIG_DIR}/git/ignore"
  TMUX_CONF="${TARGET_HOME}/.tmux.conf"

  as_user "mkdir -p '${LOCAL_BIN}' '${CONFIG_DIR}' '${BASHRC_D}' '${CONFIG_DIR}/git'"
}

install_starship() {
  if as_user "command -v starship >/dev/null 2>&1"; then
    log "Starship already installed. Skipping."
    return
  fi

  log "Installing Starship to ${LOCAL_BIN} ..."
  as_user "curl -sS https://starship.rs/install.sh | sh -s -- -b '${LOCAL_BIN}' -y"
}

write_starship_toml() {
  log "Writing ${STARSHIP_TOML} (backup if exists) ..."
  if as_user "[[ -f '${STARSHIP_TOML}' ]]"; then
    TS="$(date +%Y%m%d_%H%M%S)"
    as_user "cp -a '${STARSHIP_TOML}' '${STARSHIP_TOML}.bak_${TS}'"
  fi

  cat > /tmp/starship.toml <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'

add_newline = false
command_timeout = 750

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

enable_bashrc_blocks() {
  log "Enabling bash shortcuts + starship init (guarded) ..."

  # Ensure ~/.local/bin on PATH
  if ! as_user "grep -q 'pi-nice: local bin' '${BASHRC}' 2>/dev/null"; then
    as_user "cat >> '${BASHRC}' <<'EOF'

# --- pi-nice: local bin ---
export PATH=\"\$HOME/.local/bin:\$PATH\"
EOF"
  fi

  # Ensure ~/.bashrc.d sourcing
  if ! as_user "grep -q 'pi-nice: source bashrc.d' '${BASHRC}' 2>/dev/null"; then
    as_user "cat >> '${BASHRC}' <<'EOF'

# --- pi-nice: source bashrc.d ---
if [ -d \"\$HOME/.bashrc.d\" ]; then
  for f in \"\$HOME/.bashrc.d/\"*.sh; do
    [ -r \"\$f\" ] && . \"\$f\"
  done
fi
EOF"
  fi

  # Write aliases file (as user)
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

  # Starship init guarded
  if ! as_user "grep -q 'pi-nice: starship init' '${BASHRC}' 2>/dev/null"; then
    as_user "cat >> '${BASHRC}' <<'EOF'

# --- pi-nice: starship init ---
if command -v starship >/dev/null 2>&1; then
  eval \"\$(starship init bash)\"
fi
EOF"
  fi
}

conda_prompt_sanity() {
  if [[ -x /opt/conda/bin/conda ]]; then
    log "Setting conda changeps1 False (prevents conda from modifying PS1)..."
    /opt/conda/bin/conda config --set changeps1 False || true
  else
    log "Conda not found at /opt/conda/bin/conda (skipping conda prompt setting)."
  fi
}

install_firacode_nerd_font() {
  log "Installing FiraCode Nerd Font (best effort) ..."
  FONT_DIR="${TARGET_HOME}/.local/share/fonts/FiraCodeNerdFont"
  as_user "mkdir -p '${FONT_DIR}'"

  # Requires jq + tar already (bootstrap has jq, tar is base)
  TAG="$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r .tag_name)"
  if [[ -z "${TAG}" || "${TAG}" == "null" ]]; then
    log "Could not resolve Nerd Fonts latest tag; skipping font install."
    return
  fi

  URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${TAG}/FiraCode.tar.xz"
  TMP="$(mktemp -d)"
  ARCHIVE="${TMP}/FiraCode.tar.xz"

  as_user "curl -fsSL '${URL}' -o '${ARCHIVE}'"
  as_user "tar -xf '${ARCHIVE}' -C '${FONT_DIR}'"
  rm -rf "${TMP}"

  if as_user "command -v fc-cache >/dev/null 2>&1"; then
    as_user "fc-cache -f '${TARGET_HOME}/.local/share/fonts' >/dev/null 2>&1 || true"
  fi
}

write_global_gitignore() {
  log "Writing global gitignore + configuring git ..."

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

  as_user "git config --global core.excludesfile '${GITIGNORE_GLOBAL}'"
}

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
  require_sudo
  resolve_target_user
  user_path_init

  install_starship
  write_starship_toml
  enable_bashrc_blocks
  conda_prompt_sanity
  install_firacode_nerd_font
  write_global_gitignore
  write_tmux_conf

  log "Nice setup complete."
  echo "NEXT:"
  echo "  1) Start a new shell (log out/in) or run: source ~/.bashrc"
  echo "  2) Verify: starship --version"
  echo "  3) Verify: git config --global core.excludesfile"
  echo "  4) Verify: tmux -V"
}

main "$@"

