import open3d as o3d
import numpy as np

print("open3d version:", o3d.__version__)
pc = o3d.geometry.PointCloud()
pc.points = o3d.utility.Vector3dVector(np.random.rand(1000, 3))
down = pc.voxel_down_sample(0.05)
print("voxel_down_sample OK, points:", len(down.points))
print("SMOKE TEST PASSED")
