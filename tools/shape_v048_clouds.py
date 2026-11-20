"""Sculpt the packed v048 cloud volume into banks and troughs beneath the station."""

import gzip
import json
from pathlib import Path
import sys

import numpy as np
from scipy.ndimage import map_coordinates


# Center x/z, height change, and horizontal radii in world meters.
BANKS = (
    (-42, -31, 10.0, 15, 12),
    (-14, -19, 7.0, 11, 10),
    (18, -30, 8.5, 15, 10),
    (49, -22, 6.5, 12, 12),
    (-48, 21, 6.5, 13, 11),
    (-15, 34, 7.0, 12, 9),
    (-25, 11, 4.6, 11, 8),
    (64, 16, 5.8, 12, 9),
    (-38, 0, 2.6, 10, 7),
    (-5, 1, -6.8, 12, 9),
    (30, -2, 3.4, 11, 7),
    (20, 15, -4.8, 17, 10),
    (43, 24, -5.0, 14, 11),
    (-47, -12, -3.8, 12, 8),
    (7, -12, -4.8, 13, 8),
)
# Center and radii (x, y, z) of the cloud groups below the north platform edge.
NORTH_BANKS = (
    ((-60, -0.5, -19), (7.6, 3.0, 5.3)),
    ((-48, 0.8, -31), (8.8, 3.8, 6.5)),
    ((-36, -0.6, -16), (7.2, 2.7, 4.8)),
    ((-25, 0.4, -25), (8.0, 3.4, 6.0)),
    ((-12, -1.0, -14), (6.8, 2.9, 4.7)),
    ((-6, 1.1, -35), (9.2, 3.8, 6.7)),
    ((2, 0.2, -22), (6.8, 3.5, 5.7)),
    ((12, -1.7, -13), (6.2, 2.9, 4.4)),
    ((16, 1.0, -31), (8.0, 3.7, 6.4)),
    ((24, -0.8, -18), (6.6, 3.3, 5.4)),
    ((34, 0.6, -24), (6.6, 3.6, 5.4)),
    ((38, -2.8, -11), (6.3, 2.8, 4.1)),
    ((42, 0.2, -36), (8.2, 3.7, 6.5)),
    ((48, -0.5, -16), (6.5, 3.4, 4.7)),
    ((57, 1.3, -28), (8.6, 3.5, 5.9)),
    ((66, -0.9, -19), (7.4, 3.0, 5.2)),
)
# The existing Godot sun direction, used only to shade the deformed cloud field.
SUN = np.array((-0.69, 0.45, -0.56), dtype=np.float32)


def smoothstep(start, end, values):
    amount = np.clip((values - start) / (end - start), 0, 1)
    return amount * amount * (3 - 2 * amount)


def noise(rng, x, z, period):
    coordinates = np.stack(((z - z.min()) / period + 1, (x - x.min()) / period + 1))
    shape = tuple(int(np.ceil(axis.max())) + 3 for axis in coordinates)
    values = rng.uniform(-1, 1, size=shape).astype(np.float32)
    return np.clip(map_coordinates(values, coordinates, order=3), -1, 1)


def deform(packed, offset, step_y):
    density = packed[..., 0].astype(np.float32) / 255
    weighted_light = density * (packed[..., 1].astype(np.float32) / 255)
    depth, height, width = density.shape
    displaced = np.empty_like(density)
    light = np.empty_like(density)
    z_index, x_index = np.indices((depth, width))
    for height_index in range(height):
        source = np.clip(height_index - offset / step_y, 0, height - 1)
        low = np.floor(source).astype(np.intp)
        high = np.minimum(low + 1, height - 1)
        fraction = source - low
        low_density = density[z_index, low, x_index]
        high_density = density[z_index, high, x_index]
        displaced[:, height_index, :] = low_density + fraction * (high_density - low_density)
        low_light = weighted_light[z_index, low, x_index]
        high_light = weighted_light[z_index, high, x_index]
        light[:, height_index, :] = low_light + fraction * (high_light - low_light)
    light = np.divide(light, displaced, out=np.zeros_like(light), where=displaced > 1e-6)
    return displaced, light


def relight(density, spacing, density_max):
    depth, height, width = density.shape
    dz, dx = np.indices((depth, width), dtype=np.float32)
    toward_sun = SUN * (spacing[1] / SUN[1])
    coordinates = np.stack((dz + toward_sun[2] / spacing[2], dx + toward_sun[0] / spacing[0]))
    step = np.linalg.norm(toward_sun) * density_max
    overhead = np.zeros((depth, width), dtype=np.float32)
    sunlit = np.empty_like(density)
    for index in reversed(range(height)):
        slice_density = density[:, index, :]
        sunlight_depth = overhead + slice_density * (step * 0.45)
        sunlit[:, index, :] = 0.89 * np.exp(-0.78 * sunlight_depth)
        overhead = map_coordinates(overhead + step * slice_density, coordinates, order=1, prefilter=False)
    return sunlit


def add_billow(field, axes, center, radii, strength):
    sections = []
    relative = []
    for axis, middle, radius in zip(axes, center, radii):
        start, end = axis.searchsorted((middle - 1.1 * radius, middle + 1.1 * radius))
        sections.append(slice(start, end))
        relative.append((axis[start:end] - middle) / radius)
    x, y, z = relative
    distance_squared = z[:, None, None] ** 2 + y[None, :, None] ** 2 + x[None, None, :] ** 2
    billow = strength * (1 - smoothstep(0.42, 1.08, distance_squared))
    bank = field[sections[2], sections[1], sections[0]]
    bank += (1 - bank) * billow


def volume_noise(rng, axes, period):
    samples = [(axis - axis[0]) / period + 1 for axis in axes]
    shape = tuple(int(np.ceil(axis[-1])) + 3 for axis in samples)
    lattice = rng.uniform(-1, 1, size=shape).astype(np.float32)
    coordinates = np.meshgrid(*samples, indexing="ij")
    return np.clip(map_coordinates(lattice, coordinates, order=3), -1, 1)


def north_billows(axes, volume_shape):
    field = np.zeros(volume_shape, dtype=np.float32)
    rng = np.random.default_rng(129)
    for center, radii in NORTH_BANKS:
        center, radii = np.array(center), np.array(radii)
        add_billow(field, axes, center, radii, 0.62)
        # Break up the main dome with uneven lobes along the crown and near shoulder.
        for x, y, z in ((-0.56, 0.49, 0.13), (-0.12, 0.70, -0.17),
                        (0.43, 0.47, 0.37), (-0.23, 0.06, 0.69),
                        (0.68, 0.05, 0.24), (0.26, 0.28, -0.64)):
            offset = np.array((x, y, z)) + rng.uniform(-0.18, 0.18, size=3)
            size = radii * rng.uniform((0.28, 0.40, 0.32), (0.49, 0.64, 0.53))
            lobe = center + radii * offset
            add_billow(field, axes, lobe, size, 0.56)
            tuft_offset = rng.uniform((-0.54, 0.37, 0.22), (0.54, 0.70, 0.61))
            add_billow(field, axes, lobe + size * tuft_offset, 0.54 * size, 0.47)

    # Erode crests at two scales so the domes have irregular, wispy edges.
    x, y, z = axes
    first, last = z.searchsorted((-49.0, -7.0))
    front = field[first:last]
    rim = smoothstep(0.025, 0.16, front) * (1 - smoothstep(0.63, 0.92, front))
    samples = (z[first:last], y, x)
    erosion = 0.27 * volume_noise(rng, samples, 3.15) + 0.12 * volume_noise(rng, samples, 1.65)
    front[:] = np.clip(front + rim * erosion, 0, 1)
    return field


def shape_clouds(directory):
    info = json.loads((directory / "cloud-v048.json").read_text(encoding="utf-8"))
    nx, ny, nz = info["dimensions"]
    with gzip.open(directory / "cloud-v048.rg8.gz", "rb") as source:
        packed = np.frombuffer(source.read(), dtype=np.uint8).reshape(nz, ny, nx, 2)

    lower = np.array(info["lower"], dtype=np.float32)
    upper = np.array(info["upper"], dtype=np.float32)
    spacing = (upper - lower) / (nx, ny, nz)
    x, z = np.meshgrid(
        lower[0] + (np.arange(nx, dtype=np.float32) + 0.5) * spacing[0],
        lower[2] + (np.arange(nz, dtype=np.float32) + 0.5) * spacing[2],
    )
    border = np.minimum(np.minimum(x - lower[0], upper[0] - x), np.minimum(z - lower[2], upper[2] - z))
    influence = smoothstep(1.0, 25.0, border)
    rng = np.random.default_rng(48)
    rise = 3.5 * noise(rng, x, z, 28.0) + 1.6 * noise(rng, x, z, 7.5)
    for cx, cz, change, rx, rz in BANKS:
        rise += change * np.exp(-((x - cx) / rx) ** 2 - ((z - cz) / rz) ** 2)

    density_max = info["max_density"]
    optical_depth = np.cumsum(packed[:, ::-1, :, 0] * (spacing[1] * density_max / 255), axis=1)
    surface = upper[1] - (optical_depth < 0.70).sum(axis=1) * spacing[1]
    requested = surface + rise
    # Keep the space between the low camera and the viaduct open.
    viaduct_clearance = np.exp(-((x - 24.0) / 28.0) ** 2 - ((z - 16.0) / 13.5) ** 2)
    ceiling = 5.35 - 5.35 * viaduct_clearance
    target = ceiling - np.logaddexp(0, 1.4 * (ceiling - requested)) / 1.4
    offset = ((target - surface) * influence).astype(np.float32)

    shaped, original_light = deform(packed, offset, spacing[1])
    altitude = lower[1] + (np.arange(ny, dtype=np.float32) + 0.5) * spacing[1]
    # Keep the pier feet at -1.62 m submerged in the low cloud between banks.
    bridge_mask = (1 - smoothstep(8.0, 21.0, np.abs(z))) * (1 - smoothstep(59.0, 82.0, np.abs(x)))
    mist_top = 1.35 + 0.65 * noise(rng, x, z, 20.0) + 0.42 * noise(rng, x, z, 6.0)
    mist = (0.50 * bridge_mask[:, None, :] * smoothstep(
        0.0, 2.7, mist_top[:, None, :] - altitude[None, :, None]
    )).astype(np.float32)
    mist_added = np.maximum(mist - shaped, 0)
    shaped += mist_added

    # Open gaps between the near banks while keeping the deeper layer and the far vista.
    near = smoothstep(8.0, 14.0, -z) * (1 - smoothstep(31.0, 49.0, -z))
    near *= 1 - smoothstep(59.0, 79.0, np.abs(x))
    bank_mix = near[:, None, :] * smoothstep(-8.0, -3.8, altitude)[None, :, None]
    billows = north_billows((x[0], altitude, z[:, 0]), shaped.shape)
    retained = 1 - 0.88 * bank_mix
    shaped *= retained
    mist_added *= retained
    shaped += (1 - shaped) * bank_mix * billows

    # Taper the very top against the volume bounds while keeping the crests rounded.
    shaped *= (1 - smoothstep(6.45, upper[1], altitude))[None, :, None]
    new_light = relight(shaped, spacing, density_max)
    weight = (0.55 * influence * smoothstep(0.35, 4.9, np.abs(offset)))[:, None, :]
    mist_fraction = np.divide(mist_added, shaped, out=np.zeros_like(shaped), where=shaped > 1e-6)
    shade = original_light + weight * (new_light - original_light)
    shade += mist_fraction * (0.25 + 0.55 * new_light - shade)
    # Add skylight through the rounded shoulders, including on the backlit side.
    first, last = z[:, 0].searchsorted((-50.0, -7.0))
    north = slice(first, last)
    near_density = shaped[north]
    sky_depth = np.cumsum(near_density[:, ::-1, :], axis=1)[:, ::-1, :] * (spacing[1] * density_max)
    sky_exposure = np.exp(-0.72 * sky_depth)
    dz, dy, dx = np.gradient(billows[north], spacing[2], spacing[1], spacing[0])
    slope = np.sqrt(dx * dx + dy * dy + dz * dz + 0.075 ** 2)
    crown = np.maximum(-dy, 0) / slope
    bank_light = 0.10 + 0.65 * new_light[north] + (0.14 + 0.19 * crown) * sky_exposure
    shade[north] += bank_mix[north] * (bank_light - shade[north])
    result = np.rint(np.clip(np.stack((shaped, shade), axis=-1), 0, 1) * 255).astype(np.uint8)
    write_grid(directory / "cloud-relief-v048.rg8.gz", result)

    # WebGL 2 guarantees 256 texels per axis. Average sunlight by cloud density.
    cells = result.reshape(nz // 2, 2, ny // 2, 2, nx // 2, 2, 2).astype(np.float32)
    density = cells[..., 0]
    summed = density.sum(axis=(1, 3, 5))
    light_sum = (density * cells[..., 1]).sum(axis=(1, 3, 5))
    sunlight = np.divide(light_sum, summed, out=np.zeros_like(light_sum), where=summed > 0)
    web_grid = np.rint(np.stack((summed / 8, sunlight), axis=-1)).astype(np.uint8)
    write_grid(directory / "cloud-web-v048.rg8.gz", web_grid)
    info["dimensions"] = [nx // 2, ny // 2, nz // 2]
    (directory / "cloud-web-v048.json").write_text(
        json.dumps(info, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def write_grid(path, data):
    with path.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=5, mtime=0) as output:
            output.write(data.tobytes())


if __name__ == "__main__":
    shape_clouds(Path(sys.argv[1]).resolve())
