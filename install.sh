#!/usr/bin/env bash
# unitree_mujoco (Python) installer
# Usage: ./install.sh [env_name]
set -euo pipefail

ENV_NAME="${1:-unitree_mujoco}"
PY_VERSION="3.10"

case "${PYPI_MIRROR:-}" in
    "")     PYPI_EXTRA_INDEX="" ;;
    tuna)   PYPI_EXTRA_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple" ;;
    aliyun) PYPI_EXTRA_INDEX="https://mirrors.aliyun.com/pypi/simple/" ;;
    *)      PYPI_EXTRA_INDEX="$PYPI_MIRROR" ;;
esac

PIP_NET_FLAGS=(--retries 10 --timeout 180)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_DIR="${UNITREE_SDK_DIR:-$REPO_ROOT/third_party/unitree_sdk2_python}"
SDK_GIT="${UNITREE_SDK_GIT:-https://github.com/unitreerobotics/unitree_sdk2_python.git}"

# ----- locate conda --------------------------------------------------------
if command -v conda >/dev/null 2>&1; then
    CONDA_BIN="$(command -v conda)"
elif [[ -x "$HOME/miniconda3/bin/conda" ]]; then
    CONDA_BIN="$HOME/miniconda3/bin/conda"
elif [[ -x "$HOME/anaconda3/bin/conda" ]]; then
    CONDA_BIN="$HOME/anaconda3/bin/conda"
else
    echo "ERROR: conda not found. Install Miniconda first." >&2
    exit 1
fi
CONDA_BASE="$("$CONDA_BIN" info --base)"
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"

echo "[1/5] Using conda at: $CONDA_BIN"
echo "      Target env:     $ENV_NAME (python $PY_VERSION)"

# ----- create / reuse env --------------------------------------------------
if conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    echo "[2/5] Env '$ENV_NAME' already exists, reusing."
else
    echo "[2/5] Creating env '$ENV_NAME'..."
    conda create -y -n "$ENV_NAME" "python=$PY_VERSION" pip
fi
conda activate "$ENV_NAME"
if [[ "${CONDA_DEFAULT_ENV:-}" != "$ENV_NAME" ]]; then
    echo "ERROR: failed to activate env $ENV_NAME" >&2
    exit 1
fi
python -m pip install --upgrade pip

EXTRA_ARGS=()
if [[ -n "$PYPI_EXTRA_INDEX" ]]; then
    EXTRA_ARGS+=(--extra-index-url "$PYPI_EXTRA_INDEX")
fi

# ----- core pip deps -------------------------------------------------------
echo "[3/5] Installing mujoco, pygame, numpy..."
python -m pip install "${PIP_NET_FLAGS[@]}" "${EXTRA_ARGS[@]}" \
    mujoco pygame "numpy<2"

# ----- unitree_sdk2_python -------------------------------------------------
# Not on PyPI; clone (or reuse) the upstream repo and `pip install -e`.
echo "[4/5] Installing unitree_sdk2_python (from source)..."
mkdir -p "$(dirname "$SDK_DIR")"
if [[ -d "$SDK_DIR/.git" ]]; then
    echo "      Reusing existing clone at $SDK_DIR"
else
    echo "      Cloning $SDK_GIT -> $SDK_DIR"
    git clone --depth 1 "$SDK_GIT" "$SDK_DIR"
fi

if ! python -m pip install "${PIP_NET_FLAGS[@]}" "${EXTRA_ARGS[@]}" -e "$SDK_DIR"; then
    cat >&2 <<EOF

ERROR: unitree_sdk2_python install failed.

This usually means cyclonedds wheel build couldn't find the cyclonedds C library.
Workaround: install cyclonedds from source, then re-run this script.
  See: https://github.com/unitreerobotics/unitree_sdk2_python#troubleshooting
EOF
    exit 1
fi

# ----- sanity check --------------------------------------------------------
echo "[5/5] Sanity check..."
python - <<'PY'
import importlib, sys
for mod in ("mujoco", "pygame", "numpy", "unitree_sdk2py"):
    try:
        importlib.import_module(mod)
        print(f"  ok: {mod}")
    except Exception as e:
        print(f"  FAIL: {mod} -> {e}", file=sys.stderr)
        sys.exit(1)
PY

echo
echo "Install complete."
echo "  Activate:  conda activate $ENV_NAME"
echo "  Run:       ./start.sh"
