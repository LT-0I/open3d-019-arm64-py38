#!/usr/bin/env bash
# 为 OrangePi5 (aarch64 / Ubuntu 20.04 / Python 3.8) 构建 Open3D 0.19.0 wheel
#
# 适用两种机器（脚本自动判断）：
#   - 原生 ARM64 主机（如 阿里云倚天710 ECS / 任意 aarch64 服务器）→ 原生速度，约 40-90 分钟
#   - x86_64 主机 → 自动注册 QEMU 跑 arm64 容器，约 6-20 小时（可后台挂着）
#
# 前置：已装 docker、git、curl；x86 上需能 docker run --privileged。
# 产物：当前目录下 open3d-0.19.0-cp38-cp38-linux_aarch64.whl
#
# 设备端安装（OrangePi5 Ubuntu 20.04）：
#   sudo apt install -y libgfortran5 libgomp1 libx11-6 libgl1
#   python3 -m pip install --upgrade pip      # 旧 pip 不认 manylinux_2_31 标签，必须先升级
#   python3 -m pip install open3d-0.19.0-cp38-cp38-manylinux_2_31_aarch64.whl
set -euo pipefail

WORK="${1:-$PWD/open3d-build}"
PATCH_URL="https://api.github.com/repos/isl-org/Open3D/pulls/7271/files"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 宿主架构: $(uname -m)"
if [ "$(uname -m)" != "aarch64" ]; then
  echo "==> 非 ARM64 主机，注册 QEMU binfmt（需要 --privileged）..."
  docker run --privileged --rm tonistiigi/binfmt --install arm64
  echo "    注意：QEMU 仿真下编译很慢（6-20h），建议 nohup/tmux 后台跑。"
fi

mkdir -p "$WORK" && cd "$WORK"
if [ ! -d Open3D ]; then
  echo "==> Clone Open3D v0.19.0 ..."
  git clone --recursive --branch v0.19.0 --depth 1 https://github.com/isl-org/Open3D.git
fi
cd Open3D

echo "==> 应用 ARM64 修复补丁 (PR #7271: 治 static TLS import 崩溃) ..."
if [ -f "$SCRIPT_DIR/open3d-arm64-fix.patch" ]; then
  PATCH_FILE="$SCRIPT_DIR/open3d-arm64-fix.patch"
else
  # 没有本地补丁文件就从 GitHub 现取 PR #7271 的 3 个关键文件补丁
  echo "    本地无补丁文件，从 GitHub 拉取 PR #7271 ..."
  PATCH_FILE="$(mktemp)"
  curl -s "$PATCH_URL?per_page=100" | python3 -c "
import sys, json
keep = {'3rdparty/find_dependencies.cmake','3rdparty/openblas/openblas.cmake','util/install_deps_ubuntu.sh'}
out=[]
for f in json.load(sys.stdin):
    if f['filename'] in keep and f.get('patch'):
        out += ['--- a/%s'%f['filename'], '+++ b/%s'%f['filename'], f['patch']]
open('$PATCH_FILE','w').write('\n'.join(out)+'\n')
"
fi
# 确保补丁链接 libgcc_s.so（上游 PR #7271 初版误写 libgcc.so，cmake 会找不到）
sed -i 's/libgcc\${CMAKE_SHARED_LIBRARY_SUFFIX}/libgcc_s${CMAKE_SHARED_LIBRARY_SUFFIX}/' "$PATCH_FILE" 2>/dev/null || true
# 已打过就跳过（幂等）
if patch -p1 --dry-run < "$PATCH_FILE" >/dev/null 2>&1; then
  patch -p1 < "$PATCH_FILE"
  echo "    补丁应用成功。"
else
  echo "    补丁已应用或不适用，跳过（若首次运行请检查）。"
fi

echo "==> 接受 Anaconda 频道 ToS(2025 起强制，v0.19.0 的 Dockerfile 早于此改动) ..."
if ! grep -q CONDA_PLUGINS_AUTO_ACCEPT_TOS docker/Dockerfile.openblas; then
  sed -i '/^RUN conda create -y -n open3d/i RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main --channel https://repo.anaconda.com/pkgs/r || true' docker/Dockerfile.openblas
  sed -i '/^RUN conda tos accept/i ENV CONDA_PLUGINS_AUTO_ACCEPT_TOS=yes' docker/Dockerfile.openblas
fi

echo "==> 用官方 docker 配方构建 (openblas-arm64-py38, BASE=arm64v8/ubuntu:20.04) ..."
time ./docker/docker_build.sh openblas-arm64-py38

echo
echo "==> 完成，产物 wheel："
ls -lh ./*.whl
echo
echo "把上面的 .whl 拷到 OrangePi5，然后："
echo "  sudo apt install -y libgfortran5 libgomp1 libx11-6 libgl1"
echo "  python3 -m pip install --upgrade pip   # 旧 pip 不认 manylinux_2_31，必须先升级"
echo "  python3 -m pip install $(ls ./*.whl | head -1 | xargs basename)"
