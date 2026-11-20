"""Convert the two authored v048 OpenVDB grids to one Godot 3D texture."""

import gzip
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

if os.name == "nt":
    _dlls = os.add_dll_directory(str(Path(sys.prefix, "Library", "bin")))

import numpy as np
import openvdb


def convert(source, metadata_path, output):
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    lower, upper = np.array(metadata["cloud"]["bounds"])
    native_spacing = 0.31
    nx, nz, ny = (int(value) for value in np.rint((upper - lower) / native_spacing))
    if nx % 2 or ny % 2:
        raise ValueError("Expected an even v048 grid width and depth")

    # OpenVDB's Windows Python binding requires an ASCII name when opening a file.
    origin = Path.cwd()
    with tempfile.TemporaryDirectory() as scratch:
        shutil.copyfile(source, Path(scratch, "v048.vdb"))
        try:
            os.chdir(scratch)
            grids, _ = openvdb.readAll("v048.vdb")
        finally:
            os.chdir(origin)

    grids = {grid.name: grid for grid in grids}
    density = np.zeros((nx, ny, nz), dtype=np.float32)
    sunlit = np.zeros_like(density)
    grids["density"].copyToArray(density)
    grids[metadata["cloud"]["lighting_grid"]].copyToArray(sunlit)
    sunlit *= density

    def filtered(grid):
        return grid.reshape(nx // 2, 2, ny // 2, 2, nz).mean((1, 3))

    density_low = filtered(density)
    sunlight_low = np.divide(filtered(sunlit), density_low, out=np.zeros_like(density_low), where=density_low > 1e-6)
    packed = np.stack((density_low / 1.2, sunlight_low), axis=-1)
    # Godot z points toward -Blender-y. Image slices run z, y, x.
    packed = np.rint(np.clip(packed[:, ::-1], 0, 1) * 255).astype(np.uint8).transpose(1, 2, 0, 3)

    output.mkdir(parents=True, exist_ok=True)
    with gzip.open(output / "cloud-v048.rg8.gz", "wb", compresslevel=5) as file:
        file.write(packed.tobytes())
    (output / "cloud-v048.json").write_text(json.dumps({
        "dimensions": [nx // 2, nz, ny // 2],
        "lower": lower.tolist(), "upper": upper.tolist(),
        "max_density": 1.2,
        "source": source.name,
        "grids": ["density", metadata["cloud"]["lighting_grid"]],
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Godot cloud volume: {nx // 2} x {nz} x {ny // 2}, from {source.name}")


if __name__ == "__main__":
    convert(*(Path(value).resolve() for value in sys.argv[1:4]))
