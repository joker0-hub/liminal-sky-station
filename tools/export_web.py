"""Build the Godot Web export with browser-sized textures in an isolated copy."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory


PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = PROJECT.parent / "liminal-godot-web"
DEFAULT_GODOT = (
    Path(os.environ["LOCALAPPDATA"]) / "LiminalSkyStation/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
    if "LOCALAPPDATA" in os.environ
    else Path(shutil.which("godot") or "godot")
)


def limit_textures(staged_project):
    # These overrides apply to the temporary Web import.
    for source in (staged_project / "assets/v048").glob("*_basecolor.jpg"):
        metadata = source.with_suffix(".jpg.import")
        settings = metadata.read_text(encoding="utf-8")
        limit = 4096 if "行李箱" in source.name else 2048
        settings = settings.replace("process/size_limit=0", f"process/size_limit={limit}")
        settings = settings.replace("compress/mode=0", "compress/mode=1")
        settings = settings.replace("compress/lossy_quality=0.7", "compress/lossy_quality=0.90")
        metadata.write_text(settings, encoding="utf-8")

    for source in (staged_project / "assets/textures").glob("*.exr.import"):
        settings = source.read_text(encoding="utf-8")
        # Keep the long, narrow floor bakes sharp along the platform.
        limit = 1536 if source.name.startswith("sky-") else 2048
        settings = settings.replace("process/size_limit=0", f"process/size_limit={limit}")
        if source.name.startswith("sky-glass-"):
            settings = settings.replace("mipmaps/generate=false", "mipmaps/generate=true")
        source.write_text(settings, encoding="utf-8")

    for source in (staged_project / "assets/textures").glob("stone-*.import"):
        settings = source.read_text(encoding="utf-8")
        source.write_text(settings.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8")


def optimize_geometry(scratch, staged_project):
    npm = shutil.which("npm.cmd" if os.name == "nt" else "npm")
    node = shutil.which("node")
    if not npm or not node:
        raise SystemExit("Node.js and npm are required to optimize the Web meshes.")
    tool = scratch / "optimize_web_meshes.mjs"
    shutil.copy2(PROJECT / "tools" / tool.name, tool)
    subprocess.run(
        [
            npm, "install", "--prefix", str(scratch), "--no-save", "--no-package-lock",
            "--no-audit", "--no-fund", "--ignore-scripts", "@gltf-transform/core@4.5.1",
            "@gltf-transform/extensions@4.5.1", "@gltf-transform/functions@4.5.1", "meshoptimizer@1.3.0",
        ],
        check=True,
    )
    models = staged_project / "assets/v048"
    subprocess.run([node, str(tool), str(models / "station-v048.glb"), str(models / "train-v048.glb")], check=True)


def export(godot, destination):
    with TemporaryDirectory(prefix="liminal-godot-web-") as working:
        scratch = Path(working).resolve()
        staged_project = scratch / "project"
        staged_project.mkdir()
        for folder in ("assets", "scripts", "shaders", "web"):
            shutil.copytree(PROJECT / folder, staged_project / folder)
        for name in ("project.godot", "station.tscn", "export_presets.cfg"):
            shutil.copy2(PROJECT / name, staged_project / name)
        limit_textures(staged_project)
        optimize_geometry(scratch, staged_project)

        output = scratch / "output"
        output.mkdir()
        subprocess.run(
            [str(godot), "--headless", "--path", str(staged_project), "--export-release", "Web", str(output / "index.html")],
            check=True,
        )
        for license_file in (PROJECT / "assets/fonts").glob("*-OFL.txt"):
            shutil.copy2(license_file, output)

        destination.mkdir(parents=True, exist_ok=True)
        for file in sorted(output.iterdir(), key=lambda path: path.name == "index.html"):
            replacement = destination / (file.name + ".tmp")
            shutil.copy2(file, replacement)
            replacement.replace(destination / file.name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=os.environ.get("LIMINAL_GODOT_EXE", DEFAULT_GODOT))
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    export(args.godot.resolve(strict=True), args.output.resolve())
