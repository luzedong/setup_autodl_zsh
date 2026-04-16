#!/usr/bin/env bash
set -euo pipefail

INSTALL_URL="https://gitee.com/jinzcdev/ohmyzsh-with-plugins/raw/main/install_ohmyzsh.sh"
TMP_ROOT="${AUTODL_TMP_ROOT:-/root/autodl-tmp}"
CACHE_ROOT="$TMP_ROOT/cache"
PYPI_INDEX_URL="${PYPI_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
PYPI_EXTRA_INDEX_URL="${PYPI_EXTRA_INDEX_URL:-}"
CONDA_MIRROR_ROOT="${CONDA_MIRROR_ROOT:-https://mirrors.tuna.tsinghua.edu.cn/anaconda}"
DEFAULT_CONDA_ENV="${DEFAULT_CONDA_ENV:-py313}"
DEFAULT_CONDA_PYTHON="${DEFAULT_CONDA_PYTHON:-3.13}"

upsert_managed_block() {
  local rc_file="$1"
  local start_marker="$2"
  local end_marker="$3"

  touch "$rc_file"
  local tmp_file
  tmp_file="$(mktemp)"
  awk -v s="$start_marker" -v e="$end_marker" '
    $0 == s { skip = 1; next }
    $0 == e { skip = 0; next }
    skip != 1 { print }
  ' "$rc_file" >"$tmp_file"
  mv "$tmp_file" "$rc_file"
}

append_env_block_once() {
  local rc_file="$1"
  local start_marker="# >>> autodl tmp storage >>>"
  local end_marker="# <<< autodl tmp storage <<<"

  upsert_managed_block "$rc_file" "$start_marker" "$end_marker"

  cat >>"$rc_file" <<EOF

$start_marker
export AUTODL_TMP_ROOT="$TMP_ROOT"
export TMPDIR="$TMP_ROOT/tmp"
export TEMP="$TMP_ROOT/tmp"
export TMP="$TMP_ROOT/tmp"
export XDG_CACHE_HOME="$CACHE_ROOT"
export PIP_CACHE_DIR="$CACHE_ROOT/pip"
export UV_CACHE_DIR="$CACHE_ROOT/uv"
export UV_PYTHON_INSTALL_DIR="$TMP_ROOT/uv/python"
export MODELSCOPE_CACHE="$CACHE_ROOT/modelscope"
export HF_HOME="$CACHE_ROOT/huggingface"
export HUGGINGFACE_HUB_CACHE="$CACHE_ROOT/huggingface/hub"
export TRANSFORMERS_CACHE="$CACHE_ROOT/huggingface/transformers"
export TORCH_HOME="$CACHE_ROOT/torch"
export MPLCONFIGDIR="$CACHE_ROOT/matplotlib"
export PYTHONUSERBASE="$TMP_ROOT/python-user-base"
export CONDA_PKGS_DIRS="$TMP_ROOT/conda/pkgs"
export CONDA_ENVS_PATH="$TMP_ROOT/conda/envs"
export PIP_INDEX_URL="$PYPI_INDEX_URL"
export UV_INDEX_URL="$PYPI_INDEX_URL"
export UV_DEFAULT_INDEX="$PYPI_INDEX_URL"
export PIP_EXTRA_INDEX_URL="$PYPI_EXTRA_INDEX_URL"
if [ -d "/root/miniconda3/condabin" ]; then
  export PATH="/root/miniconda3/condabin:/root/miniconda3/bin:\$PATH"
fi
$end_marker
EOF
}

append_autocd_block_once() {
  local rc_file="$1"
  local start_marker="# >>> autodl startup cwd >>>"
  local end_marker="# <<< autodl startup cwd <<<"

  upsert_managed_block "$rc_file" "$start_marker" "$end_marker"

  cat >>"$rc_file" <<EOF

$start_marker
if [ -d "$TMP_ROOT" ] && [[ \$- == *i* ]]; then
  cd "$TMP_ROOT"
fi
$end_marker
EOF
}

append_force_zsh_block_once() {
  local rc_file="$1"
  local start_marker="# >>> autodl force zsh >>>"
  local end_marker="# <<< autodl force zsh <<<"

  upsert_managed_block "$rc_file" "$start_marker" "$end_marker"

  cat >>"$rc_file" <<'EOF'

# >>> autodl force zsh >>>
if [ -z "${ZSH_VERSION:-}" ] && [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]]; then
  if command -v zsh >/dev/null 2>&1; then
    exec zsh -l
  fi
fi
# <<< autodl force zsh <<<
EOF
}

append_conda_init_block_once() {
  local rc_file="$1"
  local shell_name="$2"
  local start_marker="# >>> autodl conda init >>>"
  local end_marker="# <<< autodl conda init <<<"

  upsert_managed_block "$rc_file" "$start_marker" "$end_marker"

  cat >>"$rc_file" <<EOF

$start_marker
if [[ \$- == *i* ]]; then
  _autodl_conda_bin="\${CONDA_EXE:-}"
  if [ -z "\$_autodl_conda_bin" ]; then
    _autodl_conda_bin="\$(command -v conda 2>/dev/null || true)"
  fi
  if [ -z "\$_autodl_conda_bin" ] && [ -x "/root/miniconda3/bin/conda" ]; then
    _autodl_conda_bin="/root/miniconda3/bin/conda"
  fi
  if [ -z "\$_autodl_conda_bin" ] && [ -x "/opt/conda/bin/conda" ]; then
    _autodl_conda_bin="/opt/conda/bin/conda"
  fi
  if [ -n "\$_autodl_conda_bin" ]; then
    __autodl_conda_setup="\$(\"\$_autodl_conda_bin\" shell.$shell_name hook 2>/dev/null || true)"
    if [ -n "\$__autodl_conda_setup" ]; then
      eval "\$__autodl_conda_setup"
    else
      _autodl_conda_base="\$(\"\$_autodl_conda_bin\" info --base 2>/dev/null || true)"
      if [ -n "\$_autodl_conda_base" ] && [ -f "\$_autodl_conda_base/etc/profile.d/conda.sh" ]; then
        . "\$_autodl_conda_base/etc/profile.d/conda.sh"
      fi
      unset _autodl_conda_base
    fi
    unset __autodl_conda_setup
  fi
  unset _autodl_conda_bin
fi
$end_marker
EOF
}

append_conda_auto_activate_block_once() {
  local rc_file="$1"
  local start_marker="# >>> autodl auto conda env >>>"
  local end_marker="# <<< autodl auto conda env <<<"

  upsert_managed_block "$rc_file" "$start_marker" "$end_marker"

  cat >>"$rc_file" <<EOF

$start_marker
if [[ \$- == *i* ]]; then
  if command -v conda >/dev/null 2>&1; then
    if [ "\${CONDA_DEFAULT_ENV:-}" != "$DEFAULT_CONDA_ENV" ]; then
      conda activate "$DEFAULT_CONDA_ENV" >/dev/null 2>&1 || true
    fi
  fi
fi
$end_marker
EOF
}

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

migrate_and_link_dir() {
  local src="$1"
  local dst="$2"

  ensure_dir "$(dirname "$src")"
  ensure_dir "$dst"

  if [ -L "$src" ]; then
    return
  fi

  if [ -d "$src" ]; then
    if [ -n "$(ls -A "$src" 2>/dev/null || true)" ]; then
      cp -a "$src"/. "$dst"/ 2>/dev/null || true
    fi
    rm -rf "$src"
  elif [ -e "$src" ]; then
    return
  fi

  ln -s "$dst" "$src"
}

echo "[1/9] Creating storage directories under $TMP_ROOT ..."
ensure_dir "$TMP_ROOT/tmp"
ensure_dir "$CACHE_ROOT/pip"
ensure_dir "$CACHE_ROOT/uv"
ensure_dir "$CACHE_ROOT/modelscope"
ensure_dir "$CACHE_ROOT/huggingface/hub"
ensure_dir "$CACHE_ROOT/huggingface/transformers"
ensure_dir "$CACHE_ROOT/torch"
ensure_dir "$CACHE_ROOT/matplotlib"
ensure_dir "$TMP_ROOT/python-user-base"
ensure_dir "$TMP_ROOT/conda/pkgs"
ensure_dir "$TMP_ROOT/conda/envs"
ensure_dir "$TMP_ROOT/uv/python"

echo "[2/9] Checking curl..."
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not found. Please install curl first."
  exit 1
fi

echo "[3/9] Checking zsh..."
if ! command -v zsh >/dev/null 2>&1; then
  echo "zsh is required but not found. Please install zsh first."
  exit 1
fi

echo "[4/9] Installing oh-my-zsh with plugins..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL "$INSTALL_URL")"
fi

echo "[5/9] Writing env vars to shell profiles..."
append_env_block_once "$HOME/.bashrc"
append_env_block_once "$HOME/.zshrc"
append_env_block_once "$HOME/.bash_profile"
append_env_block_once "$HOME/.zprofile"
append_autocd_block_once "$HOME/.bashrc"
append_autocd_block_once "$HOME/.zshrc"
append_autocd_block_once "$HOME/.bash_profile"
append_autocd_block_once "$HOME/.zprofile"
append_force_zsh_block_once "$HOME/.bashrc"
append_force_zsh_block_once "$HOME/.bash_profile"
append_conda_init_block_once "$HOME/.bashrc" "bash"
append_conda_init_block_once "$HOME/.bash_profile" "bash"
append_conda_init_block_once "$HOME/.zshrc" "zsh"
append_conda_init_block_once "$HOME/.zprofile" "zsh"
append_conda_auto_activate_block_once "$HOME/.bashrc"
append_conda_auto_activate_block_once "$HOME/.zshrc"
append_conda_auto_activate_block_once "$HOME/.bash_profile"
append_conda_auto_activate_block_once "$HOME/.zprofile"

echo "[6/9] Migrating common cache directories to $CACHE_ROOT ..."
migrate_and_link_dir "$HOME/.cache/pip" "$CACHE_ROOT/pip"
migrate_and_link_dir "$HOME/.cache/uv" "$CACHE_ROOT/uv"
migrate_and_link_dir "$HOME/.cache/modelscope" "$CACHE_ROOT/modelscope"
migrate_and_link_dir "$HOME/.cache/huggingface" "$CACHE_ROOT/huggingface"
migrate_and_link_dir "$HOME/.cache/torch" "$CACHE_ROOT/torch"

echo "[7/9] Configuring pip/uv/conda mirrors and paths..."
mkdir -p "$HOME/.config/pip"
cat >"$HOME/.config/pip/pip.conf" <<EOF
[global]
index-url = $PYPI_INDEX_URL
cache-dir = $CACHE_ROOT/pip
timeout = 120
EOF

if [ -n "$PYPI_EXTRA_INDEX_URL" ]; then
  cat >>"$HOME/.config/pip/pip.conf" <<EOF
extra-index-url = $PYPI_EXTRA_INDEX_URL
EOF
fi

if command -v conda >/dev/null 2>&1; then
  conda config --remove-key pkgs_dirs >/dev/null 2>&1 || true
  conda config --remove-key envs_dirs >/dev/null 2>&1 || true
  conda config --remove-key default_channels >/dev/null 2>&1 || true
  conda config --remove-key channels >/dev/null 2>&1 || true
  conda config --remove-key custom_channels >/dev/null 2>&1 || true
  conda config --add pkgs_dirs "$TMP_ROOT/conda/pkgs" >/dev/null
  conda config --add envs_dirs "$TMP_ROOT/conda/envs" >/dev/null
  conda config --add default_channels "$CONDA_MIRROR_ROOT/pkgs/main" >/dev/null
  conda config --add default_channels "$CONDA_MIRROR_ROOT/pkgs/r" >/dev/null
  conda config --add default_channels "$CONDA_MIRROR_ROOT/pkgs/msys2" >/dev/null
  conda config --add channels defaults >/dev/null
  conda config --set show_channel_urls yes >/dev/null
fi

echo "[8/9] Ensuring default conda env: $DEFAULT_CONDA_ENV (python=$DEFAULT_CONDA_PYTHON)..."
if command -v conda >/dev/null 2>&1; then
  if ! conda env list | awk '{print $1}' | grep -qx "$DEFAULT_CONDA_ENV"; then
    conda create -y -n "$DEFAULT_CONDA_ENV" "python=$DEFAULT_CONDA_PYTHON"
  fi
fi

echo "[9/9] Setting zsh as default shell..."
ZSH_PATH="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
  CURRENT_USER="${USER:-$(id -un)}"
  if command -v chsh >/dev/null 2>&1; then
    chsh -s "$ZSH_PATH" "$CURRENT_USER" || true
  fi
fi

echo "Done."
echo "Run: source ~/.bashrc && source ~/.zshrc"
echo "Then check: conda env list && conda info --envs"
