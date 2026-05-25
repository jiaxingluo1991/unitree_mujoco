#!/usr/bin/env bash
# unitree_mujoco G1 quickstart: pick a robot/scene and launch MuJoCo + DDS bridge.
# Auto-activates the unitree_mujoco conda env.
set -euo pipefail

ENV_NAME="${UNITREE_MUJOCO_ENV:-unitree_mujoco}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$REPO_ROOT/simulate_python"

# ----- locate + activate conda env ----------------------------------------
if command -v conda >/dev/null 2>&1; then
    CONDA_BIN="$(command -v conda)"
elif [[ -x "$HOME/miniconda3/bin/conda" ]]; then
    CONDA_BIN="$HOME/miniconda3/bin/conda"
elif [[ -x "$HOME/anaconda3/bin/conda" ]]; then
    CONDA_BIN="$HOME/anaconda3/bin/conda"
else
    echo "ERROR: conda not found." >&2; exit 1
fi
CONDA_BASE="$("$CONDA_BIN" info --base)"
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"

if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    echo "ERROR: conda env '$ENV_NAME' not found. Run ./install.sh first." >&2
    exit 1
fi
conda activate "$ENV_NAME"

# ----- menu ---------------------------------------------------------------
echo
echo "unitree_mujoco quickstart"
echo "  1) G1 29-DOF (humanoid, scene_29dof.xml, elastic band)"
echo "  2) G1 23-DOF (humanoid, scene_23dof.xml, elastic band)"
echo "  3) Go2     (quadruped, scene.xml)"
echo "  4) H1      (humanoid, scene.xml, elastic band)"
read -r -p "Pick [1/2/3/4]: " choice

case "$choice" in
1) ROBOT="g1";  SCENE="../unitree_robots/g1/scene_29dof.xml";  BAND="True"  ;;
2) ROBOT="g1";  SCENE="../unitree_robots/g1/scene_23dof.xml";  BAND="True"  ;;
3) ROBOT="go2"; SCENE="../unitree_robots/go2/scene.xml";       BAND="False" ;;
4) ROBOT="h1";  SCENE="../unitree_robots/h1/scene.xml";        BAND="True"  ;;
*) echo "Invalid choice." >&2; exit 1 ;;
esac

read -r -p "Use joystick? [y/N]: " js
if [[ "${js,,}" == "y" || "${js,,}" == "yes" ]]; then
    USE_JOYSTICK="1"
else
    USE_JOYSTICK="0"
fi

cd "$SIM_DIR"

echo
echo "Launching unitree_mujoco:"
echo "  robot:         $ROBOT"
echo "  scene:         $SCENE"
echo "  elastic band:  $BAND   (press 9 to attach, 7 lower, 8 lift)"
echo "  joystick:      $USE_JOYSTICK"
echo "  DDS interface: lo (domain_id from config.py)"
echo

# Override the upstream config.py via monkey-patch so we don't edit vendored files.
ROBOT="$ROBOT" SCENE="$SCENE" BAND="$BAND" USE_JOYSTICK="$USE_JOYSTICK" \
python - <<'PY'
import os, runpy, config
config.ROBOT = os.environ["ROBOT"]
config.ROBOT_SCENE = os.environ["SCENE"]
config.ENABLE_ELASTIC_BAND = os.environ["BAND"] == "True"
config.USE_JOYSTICK = int(os.environ["USE_JOYSTICK"])
runpy.run_path("unitree_mujoco.py", run_name="__main__")
PY
