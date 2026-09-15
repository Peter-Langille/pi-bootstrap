#!/usr/bin/env bash

set -euo pipefail

log()  { echo -e "\n[NICE] $*\n"; }
warn() { echo -e "\n[NICE][WARN] $*\n" >&2; }
die()  { echo -e "\n[NICE][ERROR] $*\n" >&2; exit 1; }

require_sudo() {
  [[ "${EUID}" -eq 0 ]] || die "Run as root: curl ... | sudo bash"
}

resolve_target_user() {
  [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] ||
    die "Must be run via sudo from a normal user."

  TARGET_USER="${SUDO_USER}"
  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

  [[ -n "${TARGET_HOME}" && -d "${TARGET_HOME}" ]] ||
    die "Cannot resolve home for ${TARGET_USER}"
}

as_user() {
  sudo -u "${TARGET_USER}" -H bash -lc "$*"
}

init_paths() {
  LOCAL_BIN="${TARGET_HOME}/.local/bin"
  CONFIG_DIR="${TARGET_HOME}/.config"
  BASHRC="${TARGET_HOME}/.bashrc"
  BASHRC_D="${TARGET_HOME}/.bashrc.d"
  STARSHIP_TOML="${CONFIG_DIR}/starship.toml"
  GITIGNORE_GLOBAL="${CONFIG_DIR}/git/ignore"
  TMUX_CONF="${TARGET_HOME}/.tmux.conf"

  NEWSBOAT_DIR="${CONFIG_DIR}/newsboat"
  NEWSBOAT_URLS="${NEWSBOAT_DIR}/urls"
  NEWSBOAT_CONFIG="${NEWSBOAT_DIR}/config"

  as_user "mkdir -p \
    '${LOCAL_BIN}' \
    '${CONFIG_DIR}' \
    '${BASHRC_D}' \
    '${CONFIG_DIR}/git' \
    '${NEWSBOAT_DIR}'"
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

  if ! as_user "grep -q 'pi-nice: local bin' '${BASHRC}' 2>/dev/null"; then
    as_user "cat >> '${BASHRC}' <<'EOF'
# --- pi-nice: local bin ---
export PATH=\"\$HOME/.local/bin:\$PATH\"
EOF"
  fi

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

  cat > /tmp/pi-nice.sh <<'EOF'
alias ll='ls -lah'
alias gs='git status'
alias gl='git log --oneline --decorate -20'
alias gd='git diff'
alias dc='docker compose'
EOF

  as_user "install -m 0644 /tmp/pi-nice.sh '${BASHRC_D}/pi-nice.sh'"
  rm -f /tmp/pi-nice.sh

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
  fi
}

install_firacode_nerd_font() {
  log "Installing FiraCode Nerd Font (best effort) ..."

  FONT_DIR="${TARGET_HOME}/.local/share/fonts/FiraCodeNerdFont"
  as_user "mkdir -p '${FONT_DIR}'"

  URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz"

  # IMPORTANT: create temp dir AS USER so user can write into it
  TMP="$(as_user "mktemp -d")"
  ARCHIVE="${TMP}/FiraCode.tar.xz"

  if ! as_user "curl -fSL --retry 3 --retry-delay 2 '${URL}' -o '${ARCHIVE}'"; then
    warn "Font download failed. Skipping fonts and continuing."
    as_user "rm -rf '${TMP}'" || true
    return 0
  fi

  if ! as_user "tar -xf '${ARCHIVE}' -C '${FONT_DIR}'"; then
    warn "Font extract failed. Skipping fonts and continuing."
    as_user "rm -rf '${TMP}'" || true
    return 0
  fi

  as_user "rm -rf '${TMP}'" || true

  as_user "command -v fc-cache >/dev/null 2>&1 && \
    fc-cache -f '${TARGET_HOME}/.local/share/fonts' >/dev/null 2>&1 || true"
}

write_global_gitignore() {
  log "Writing global gitignore + configuring git ..."

  cat > /tmp/gitignore_global <<'EOF'
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.vscode/
.idea/
__pycache__/
*.py[cod]
.venv/
venv/
.env
.ipynb_checkpoints/
*.log
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
set -g mouse on
set -g history-limit 20000

unbind C-b
set -g prefix C-a
bind C-a send-prefix

bind | split-window -h
bind - split-window -v

unbind '"'
unbind %

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

set -sg escape-time 10
EOF

  as_user "install -m 0644 /tmp/tmux.conf '${TMUX_CONF}'"
  rm -f /tmp/tmux.conf
}

install_newsboat_w3m() {
  log "Installing Newsboat + w3m terminal news tools..."

  export DEBIAN_FRONTEND=noninteractive

  apt-get update -y
  apt-get install -y --no-install-recommends \
    newsboat \
    w3m
}

write_newsboat_config() {
  log "Writing Newsboat RSS feeds and terminal-browser configuration..."

  as_user "mkdir -p '${NEWSBOAT_DIR}'"

  cat > /tmp/newsboat-urls <<'EOF'
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
EOF

  as_user "install -m 0644 /tmp/newsboat-urls '${NEWSBOAT_URLS}'"
  rm -f /tmp/newsboat-urls

  cat > /tmp/newsboat-config <<'EOF'
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
EOF

  as_user "install -m 0644 /tmp/newsboat-config '${NEWSBOAT_CONFIG}'"
  rm -f /tmp/newsboat-config
}

main() {
  require_sudo
  resolve_target_user
  init_paths

  install_starship
  write_starship_toml
  enable_bashrc_blocks
  conda_prompt_sanity
  install_firacode_nerd_font
  write_global_gitignore
  write_tmux_conf

  install_newsboat_w3m
  write_newsboat_config

  log "Nice setup complete."

  echo "NEXT: log out/in (new SSH session) so bashrc reloads."
  echo "NEWS: run 'newsboat', then press R to refresh all feeds."
}

main "$@"
