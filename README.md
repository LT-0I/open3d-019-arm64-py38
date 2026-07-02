# open3d-019-arm64-py38

用 GitHub Actions 的**原生 aarch64 runner** 为 **OrangePi 5 (RK3588) / Ubuntu 20.04 / Python 3.8** 构建 **Open3D 0.19.0** 的 wheel。

## 为什么需要自己编

Open3D 0.19.0 官方**没有发布任何 Linux ARM64 wheel**，因为 bug
[isl-org/Open3D#7130](https://github.com/isl-org/Open3D/issues/7130)：aarch64 上静态
`libgfortran.a` 未用 `-fPIC` 编译，导致 `import open3d` 时报
`cannot allocate memory in static TLS block`。修复见
[PR #7271](https://github.com/isl-org/Open3D/pull/7271)（进 v0.20）。

本仓库在 v0.19.0 源码上打上该修复补丁（`open3d-arm64-fix.patch`），再用官方
`docker/docker_build.sh openblas-arm64-py38` 配方（基础镜像 `arm64v8/ubuntu:20.04`，
glibc 2.31，与 OrangePi5 完全匹配）构建，并在下载前于干净的 arm64 ubuntu:20.04 + py3.8
容器里做一次真 `import` 冒烟测试。

## 用法

1. 到 **Actions** 页面手动运行 `build-open3d-019-arm64-py38`（workflow_dispatch）。
2. 约 2–3.5 小时后，在该次 run 的 **Artifacts** 下载 `open3d-0.19.0-cp38-aarch64-wheel`。
3. 在 OrangePi5 上安装：

```bash
sudo apt install -y libgfortran5 libgomp1
pip install open3d-0.19.0-cp38-cp38-linux_aarch64.whl
python3 -c "import open3d as o3d; print(o3d.__version__)"
```

> 注意：RK3588 只有 OpenGL ES，`open3d.visualization` 的 GUI 可能无法使用；
> 几何/IO/Tensor/点云算法不受影响。
