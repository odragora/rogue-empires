from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from collections import Counter, deque
import hashlib
import re
import numpy as np
from PIL import Image


@dataclass
class Config:
    seed: int = 1
    rows: int = 100
    cols: int = 100

    # Hex draw layout (odd-r offset rows)
    tile_w: int = 26
    tile_h: int = 32
    step_x: int = 23
    row_off_x: int = 12
    row_step_y: int = 17

    # Vertical displacement
    height_px: int = 80
    height_gamma: float = 1.10
    height_smooth_passes: int = 1
    height_max_neighbor_delta: int = 2

    # Landmass
    sea_level: float = 0.44
    continental_scale: int = 25
    continental_octaves: int = 3
    continental_smooth_passes: int = 2

    # Terrain features
    peaks_scale: int = 6
    peaks_octaves: int = 5
    erosion_scale: int = 8
    erosion_octaves: int = 4

    # Ridge mountains
    ridge_scale_long: int = 30
    ridge_scale_short: int = 9
    ridge_octaves: int = 4
    ridge_strength: float = 0.55

    # Mountains shaping
    mountain_level: float = 0.73
    ridge_mountain_thresh: float = 0.64
    peak_mountain_thresh: float = 0.86
    mountain_ridge_keep_base: float = 0.18
    mountain_ridge_keep_gain: float = 0.70
    mountain_peak_keep_prob: float = 0.28
    mountain_thin_passes: int = 5
    mountain_thin_remove_ge: int = 3
    mountain_thin_junction_ridge: float = 0.84
    mountain_speck_prune_passes: int = 2

    # Hills
    hill_level: float = 0.65
    hill_near_mountain_dist: int = 3
    hill_extra_prob: float = 0.40

    # Climate
    humid_scale: int = 8
    humid_octaves: int = 5
    temp_scale: int = 9
    temp_octaves: int = 5

    # Domain warp
    warp_scale: int = 8
    warp_octaves: int = 3
    warp_amp: int = 4

    persistence: float = 0.52
    lacunarity: float = 2.0
    peaks_strength: float = 0.72
    erosion_strength: float = 0.55

    # Water depth transitions
    shallow_band: int = 1
    deep_band: int = 3
    water_break_scale: int = 3
    water_break_octaves: int = 6
    water_break_amp: float = 5.0
    water_break_smooth: int = 1
    deep_core_extra: int = 2
    deep_connect_relax: int = 1
    deep_edge_lo: float = -0.35
    deep_edge_hi: float = 0.35

    # Biomes
    hot_temp: float = 0.64
    cold_temp: float = 0.36
    snow_temp: float = 0.27

    wet_humid: float = 0.66
    forest_humid: float = 0.44
    jungle_humid: float = 0.65
    dry_humid: float = 0.34
    very_dry_humid: float = 0.22

    # Jungle boost (to ensure it appears often, in clusters)
    jungle_temp_min: float = 0.46
    jungle_seed_scale: int = 5
    jungle_seed_octaves: int = 3
    jungle_seed_smooth: int = 1
    jungle_seed_thresh: float = 0.32
    jungle_extra_humid_pad: float = 0.04  # allow a little under jungle_humid

    # Lakes
    lake_noise_scale: int = 20
    lake_octaves: int = 2
    lake_strength: float = 0.35
    lake_level_boost: float = 0.05
    lake_min_coast_dist: int = 16
    lake_thresh: float = 1.40
    lake_range_bias: float = 0.55
    lake_max_mtn_dist: int = 10

    # Rivers
    river_count: int = 6
    river_source_elev: float = 0.74
    river_min_coast_dist: int = 8
    river_valley_thresh: float = 0.74
    river_max_len: int = 220
    river_prune_passes: int = 6
    river_ridge_source_thresh: float = 0.64
    river_source_max_mtn_dist: int = 10

    # Desert and wheat
    desert_scale: int = 24
    desert_octaves: int = 2
    desert_hot_boost: float = 0.10
    desert_smooth_passes: int = 3

    wheat_scale: int = 12
    wheat_octaves: int = 2
    wheat_smooth_passes: int = 1
    wheat_thresh: float = 0.54

    wheat_convert_prob: float = 0.22
    wheat_convert_scale: int = 9
    wheat_convert_octaves: int = 2
    wheat_convert_smooth: int = 1
    wheat_convert_min_temp: float = 0.34
    wheat_convert_max_temp: float = 0.78
    wheat_convert_min_humid: float = 0.30
    wheat_convert_max_humid: float = 0.62

    grass_humid_min: float = 0.36

    # Equator bias
    equator_fields_strength: float = 0.14
    equator_desert_strength: float = 0.10
    equator_forest_suppress: float = 0.06

    # Beaches
    beach_scale: int = 14
    beach_octaves: int = 2
    beach_smooth_passes: int = 1
    beach_base_p1: float = 0.50
    beach_base_p2: float = 0.18
    beach_humid_cut: float = 0.62
    beach_temp_min: float = 0.30

    # Clustering
    cluster_passes: int = 2
    cluster_min_same: int = 4
    cluster_change_prob: float = 0.65
    cluster_protect: tuple[str, ...] = ("deep_water", "water", "shallow_water", "mountains", "snow")
    cluster_only: tuple[str, ...] = (
        "grass", "forest", "jungle", "wheat", "swamp", "swamp_pads", "swamp_reeds",
        "dirt", "clay", "sand", "dunes", "tiaga",
    )


CFG = Config()

TILE_TYPES = [
    "clay", "deep_water", "water", "shallow_water", "dirt", "dunes", "forest",
    "grass", "hills", "jungle", "mountains", "river_r", "river_l", "sand",
    "snow", "tiaga", "swamp", "swamp_pads", "swamp_reeds", "wheat",
]
_TILE_RE = re.compile(r"^([a-z_]+)_(\d+)_tile\.(png|webp|bmp)$", re.IGNORECASE)


def hash01(seed: int, r: int, c: int, tag: str) -> float:
    h = hashlib.blake2b(f"{seed}|{tag}|{r}|{c}".encode("utf-8"), digest_size=8).digest()
    return (int.from_bytes(h, "little") & ((1 << 53) - 1)) / float(1 << 53)


def hex_neighbors(r: int, c: int, rows: int, cols: int):
    # Keep the neighbor logic that matches your working layout.
    if (r & 1) == 0:
        deltas = [(0, -1), (0, 1), (-1, -1), (-1, 0), (1, -1), (1, 0)]
    else:
        deltas = [(0, -1), (0, 1), (-1, 0), (-1, 1), (1, 0), (1, 1)]
    for dr, dc in deltas:
        rr = r + dr
        cc = c + dc
        if 0 <= rr < rows and 0 <= cc < cols:
            yield rr, cc


def load_tiles(folder: str = "Tiles") -> dict[str, list[Image.Image]]:
    p = Path(folder)
    if not p.exists():
        raise SystemExit(f"Folder not found: {p.resolve()}")

    groups: dict[str, list[tuple[str, Image.Image]]] = {k: [] for k in TILE_TYPES}
    for f in sorted(p.iterdir(), key=lambda x: x.name.lower()):
        m = _TILE_RE.match(f.name)
        if not m:
            continue
        t = m.group(1).lower()
        if t in groups:
            groups[t].append((f.name, Image.open(f).convert("RGBA")))

    out: dict[str, list[Image.Image]] = {}
    for t, items in groups.items():
        items.sort(key=lambda x: x[0].lower())
        out[t] = [img for _, img in items]

    missing = [t for t in TILE_TYPES if not out.get(t)]
    if missing:
        print("Warning: missing tile types:", ", ".join(missing))
    return out


def pick_variant(tiles: dict[str, list[Image.Image]], t: str, seed: int, r: int, c: int) -> Image.Image:
    arr = tiles.get(t) or tiles.get("grass") or []
    if not arr:
        raise SystemExit("No usable tiles found in Tiles folder.")
    h = hashlib.blake2b(f"{seed}|{t}|{r}|{c}".encode("utf-8"), digest_size=8).digest()
    return arr[int.from_bytes(h, "little") % len(arr)]


def normalize01(a: np.ndarray) -> np.ndarray:
    mn = float(a.min())
    mx = float(a.max())
    if mx - mn < 1e-8:
        return np.zeros_like(a, dtype=np.float32)
    return ((a - mn) / (mx - mn)).astype(np.float32)


def smooth_box(a: np.ndarray, passes: int) -> np.ndarray:
    out = a.astype(np.float32)
    for _ in range(max(0, int(passes))):
        out = (
            out
            + np.roll(out, 1, 0) + np.roll(out, -1, 0)
            + np.roll(out, 1, 1) + np.roll(out, -1, 1)
            + np.roll(np.roll(out, 1, 0), 1, 1)
            + np.roll(np.roll(out, 1, 0), -1, 1)
            + np.roll(np.roll(out, -1, 0), 1, 1)
            + np.roll(np.roll(out, -1, 0), -1, 1)
        ) / 9.0
    return out.astype(np.float32)


def ridged01(n01: np.ndarray) -> np.ndarray:
    return normalize01((1.0 - np.abs(2.0 * n01 - 1.0)).astype(np.float32))


def _rand_grid(seed: int, gh: int, gw: int) -> np.ndarray:
    return np.random.default_rng(seed).random((gh, gw), dtype=np.float32)


def value_noise_2d(shape: tuple[int, int], seed: int, scale: int) -> np.ndarray:
    h, w = shape
    scale = max(1, int(scale))
    gh = h // scale + 2
    gw = w // scale + 2
    g = _rand_grid(seed, gh, gw)

    ys = np.arange(h, dtype=np.float32) / scale
    xs = np.arange(w, dtype=np.float32) / scale

    y0 = np.floor(ys).astype(np.int32)
    x0 = np.floor(xs).astype(np.int32)
    y1 = np.clip(y0 + 1, 0, gh - 1)
    x1 = np.clip(x0 + 1, 0, gw - 1)
    y0 = np.clip(y0, 0, gh - 1)
    x0 = np.clip(x0, 0, gw - 1)

    ty = (ys - y0).astype(np.float32)[:, None]
    tx = (xs - x0).astype(np.float32)[None, :]

    g00 = g[y0[:, None], x0[None, :]]
    g01 = g[y0[:, None], x1[None, :]]
    g10 = g[y1[:, None], x0[None, :]]
    g11 = g[y1[:, None], x1[None, :]]

    a = g00 * (1.0 - tx) + g01 * tx
    b = g10 * (1.0 - tx) + g11 * tx
    return (a * (1.0 - ty) + b * ty).astype(np.float32)


def value_noise_2d_aniso(shape: tuple[int, int], seed: int, sy: int, sx: int) -> np.ndarray:
    h, w = shape
    sy = max(1, int(sy))
    sx = max(1, int(sx))
    gh = h // sy + 2
    gw = w // sx + 2
    g = _rand_grid(seed, gh, gw)

    ys = np.arange(h, dtype=np.float32) / sy
    xs = np.arange(w, dtype=np.float32) / sx

    y0 = np.floor(ys).astype(np.int32)
    x0 = np.floor(xs).astype(np.int32)
    y1 = np.clip(y0 + 1, 0, gh - 1)
    x1 = np.clip(x0 + 1, 0, gw - 1)
    y0 = np.clip(y0, 0, gh - 1)
    x0 = np.clip(x0, 0, gw - 1)

    ty = (ys - y0).astype(np.float32)[:, None]
    tx = (xs - x0).astype(np.float32)[None, :]

    g00 = g[y0[:, None], x0[None, :]]
    g01 = g[y0[:, None], x1[None, :]]
    g10 = g[y1[:, None], x0[None, :]]
    g11 = g[y1[:, None], x1[None, :]]

    a = g00 * (1.0 - tx) + g01 * tx
    b = g10 * (1.0 - tx) + g11 * tx
    return (a * (1.0 - ty) + b * ty).astype(np.float32)


def fbm(shape: tuple[int, int], seed: int, base_scale: int, octaves: int, p: float, lac: float) -> np.ndarray:
    total = np.zeros(shape, dtype=np.float32)
    amp, freq, amp_sum = 1.0, 1.0, 0.0
    for i in range(int(octaves)):
        scale = max(1, int(base_scale / freq))
        total += amp * value_noise_2d(shape, seed + 1013 * i, scale)
        amp_sum += amp
        amp *= float(p)
        freq *= float(lac)
    return total / max(1e-6, amp_sum)


def fbm_aniso(shape: tuple[int, int], seed: int, base_sy: int, base_sx: int, octaves: int, p: float, lac: float) -> np.ndarray:
    total = np.zeros(shape, dtype=np.float32)
    amp, freq, amp_sum = 1.0, 1.0, 0.0
    for i in range(int(octaves)):
        sy = max(1, int(base_sy / freq))
        sx = max(1, int(base_sx / freq))
        total += amp * value_noise_2d_aniso(shape, seed + 1013 * i, sy, sx)
        amp_sum += amp
        amp *= float(p)
        freq *= float(lac)
    return total / max(1e-6, amp_sum)


def noise_field(cfg: Config, seed_off: int, scale: int, octaves: int, smooth: int = 0) -> np.ndarray:
    a = normalize01(fbm((cfg.rows, cfg.cols), cfg.seed + seed_off, scale, octaves, cfg.persistence, cfg.lacunarity))
    return smooth_box(a, smooth)


def warp_int(a: np.ndarray, wx: np.ndarray, wy: np.ndarray) -> np.ndarray:
    rows, cols = a.shape
    rr = np.arange(rows, dtype=np.int32)[:, None]
    cc = np.arange(cols, dtype=np.int32)[None, :]
    r2 = np.clip(rr + wy.astype(np.int32), 0, rows - 1)
    c2 = np.clip(cc + wx.astype(np.int32), 0, cols - 1)
    return a[r2, c2]


def hex_bfs_distance(mask_sources: np.ndarray) -> np.ndarray:
    rows, cols = mask_sources.shape
    dist = np.full((rows, cols), 10**9, dtype=np.int32)
    q = deque()
    ys, xs = np.where(mask_sources)
    for r, c in zip(ys.tolist(), xs.tolist()):
        dist[r, c] = 0
        q.append((r, c))
    while q:
        r, c = q.popleft()
        nd = dist[r, c] + 1
        for rr, cc in hex_neighbors(r, c, rows, cols):
            if nd < dist[rr, cc]:
                dist[rr, cc] = nd
                q.append((rr, cc))
    return dist


def ocean_connected_hex(water: np.ndarray) -> np.ndarray:
    rows, cols = water.shape
    ocean = np.zeros_like(water, dtype=bool)
    q = deque()

    def push(r: int, c: int):
        if water[r, c] and not ocean[r, c]:
            ocean[r, c] = True
            q.append((r, c))

    for c in range(cols):
        push(0, c)
        push(rows - 1, c)
    for r in range(rows):
        push(r, 0)
        push(r, cols - 1)

    while q:
        r, c = q.popleft()
        for rr, cc in hex_neighbors(r, c, rows, cols):
            push(rr, cc)
    return ocean


def flood_keep(mask: np.ndarray, seeds: np.ndarray) -> np.ndarray:
    rows, cols = mask.shape
    out = np.zeros_like(mask, dtype=bool)
    q = deque()
    ys, xs = np.where(seeds & mask)
    for r, c in zip(ys.tolist(), xs.tolist()):
        out[r, c] = True
        q.append((r, c))
    while q:
        r, c = q.popleft()
        for rr, cc in hex_neighbors(r, c, rows, cols):
            if mask[rr, cc] and not out[rr, cc]:
                out[rr, cc] = True
                q.append((rr, cc))
    return out


def water_break(cfg: Config) -> np.ndarray:
    n = noise_field(cfg, 310, cfg.water_break_scale, cfg.water_break_octaves, cfg.water_break_smooth)
    return ((n - 0.5) * 2.0 * float(cfg.water_break_amp)).astype(np.float32)


def swamp_variant(seed: int, r: int, c: int) -> str:
    v = hash01(seed, r, c, "swamp")
    if v < 0.33:
        return "swamp"
    if v < 0.66:
        return "swamp_pads"
    return "swamp_reeds"


def neighbor_count(mask: np.ndarray, r: int, c: int) -> int:
    return sum(1 for rr, cc in hex_neighbors(r, c, mask.shape[0], mask.shape[1]) if mask[rr, cc])


def prune_specks(cfg: Config, mask: np.ndarray, tag: str, passes: int, kill_prob: float = 0.70) -> np.ndarray:
    out = mask.copy()
    rows, cols = out.shape
    for _ in range(max(0, int(passes))):
        kill = []
        for r in range(rows):
            for c in range(cols):
                if not out[r, c]:
                    continue
                n = neighbor_count(out, r, c)
                if n == 0:
                    kill.append((r, c))
                elif n == 1 and hash01(cfg.seed, r, c, tag) < kill_prob:
                    kill.append((r, c))
        if not kill:
            break
        for r, c in kill:
            out[r, c] = False
    return out


def thin_mountains(cfg: Config, mtn: np.ndarray, ridges: np.ndarray) -> np.ndarray:
    out = mtn.copy()
    rows, cols = out.shape
    for _ in range(max(0, int(cfg.mountain_thin_passes))):
        kill = []
        for r in range(rows):
            for c in range(cols):
                if not out[r, c]:
                    continue
                n = neighbor_count(out, r, c)
                if n >= cfg.mountain_thin_remove_ge:
                    if float(ridges[r, c]) < cfg.mountain_thin_junction_ridge:
                        kill.append((r, c))
                elif n == 0:
                    kill.append((r, c))
        if not kill:
            break
        for r, c in kill:
            out[r, c] = False
    return prune_specks(cfg, out, "mtn_speck", cfg.mountain_speck_prune_passes)


def build_fields(cfg: Config):
    shape = (cfg.rows, cfg.cols)

    cont = noise_field(cfg, 10, cfg.continental_scale, cfg.continental_octaves, cfg.continental_smooth_passes)
    cont = np.clip((cont - 0.22) / 0.78, 0.0, 1.0).astype(np.float32)

    peaks = ridged01(normalize01(fbm(shape, cfg.seed + 20, cfg.peaks_scale, cfg.peaks_octaves, cfg.persistence, cfg.lacunarity)))
    erosion = noise_field(cfg, 30, cfg.erosion_scale, cfg.erosion_octaves, 0)

    ridge_a = fbm_aniso(shape, cfg.seed + 25, cfg.ridge_scale_short, cfg.ridge_scale_long, cfg.ridge_octaves, cfg.persistence, cfg.lacunarity)
    ridge_b = fbm_aniso(shape, cfg.seed + 26, cfg.ridge_scale_long, cfg.ridge_scale_short, cfg.ridge_octaves, cfg.persistence, cfg.lacunarity)
    ridges = smooth_box(np.maximum(ridged01(normalize01(ridge_a)), ridged01(normalize01(ridge_b))), 1)

    humid0 = noise_field(cfg, 40, cfg.humid_scale, cfg.humid_octaves, 0)
    temp0 = noise_field(cfg, 50, cfg.temp_scale, cfg.temp_octaves, 0)

    wx = ((noise_field(cfg, 71, cfg.warp_scale, cfg.warp_octaves, 0) - 0.5) * 2.0 * cfg.warp_amp).astype(np.int32)
    wy = ((noise_field(cfg, 72, cfg.warp_scale, cfg.warp_octaves, 0) - 0.5) * 2.0 * cfg.warp_amp).astype(np.int32)
    humid = warp_int(humid0, wx, wy)
    temp_noise = warp_int(temp0, -wx, wy)

    peaks2 = peaks * (1.0 - cfg.erosion_strength * erosion)
    elev = normalize01(cont + cfg.peaks_strength * peaks2 + cfg.ridge_strength * ridges)

    lat = np.linspace(0.0, 1.0, cfg.rows, dtype=np.float32)
    equator = 1.0 - np.abs(lat * 2.0 - 1.0)

    temp = 0.70 * equator[:, None] + 0.30 * temp_noise
    temp = temp - 0.38 * np.clip(elev - cfg.sea_level, 0.0, 1.0)
    temp = normalize01(temp)

    land = elev >= cfg.sea_level
    dist_to_land = hex_bfs_distance(land)
    dist_to_water = hex_bfs_distance(~land)

    water_influence = np.exp(-dist_to_water.astype(np.float32) / 3.2).astype(np.float32)
    humid2 = normalize01(0.70 * humid + 0.30 * water_influence)

    return elev, peaks, ridges, humid2, temp, equator, land, dist_to_land, dist_to_water


def build_mountains(cfg: Config, land: np.ndarray, elev: np.ndarray, peaks: np.ndarray, ridges: np.ndarray, temp: np.ndarray) -> np.ndarray:
    warm = temp > cfg.cold_temp
    ridge_zone = land & warm & (elev >= (cfg.mountain_level - 0.06)) & (ridges >= cfg.ridge_mountain_thresh)
    rr = np.clip((ridges - cfg.ridge_mountain_thresh) / max(1e-6, 1.0 - cfg.ridge_mountain_thresh), 0.0, 1.0)
    keep_prob = np.clip(cfg.mountain_ridge_keep_base + cfg.mountain_ridge_keep_gain * rr, 0.0, 1.0)

    mtn = np.zeros_like(land, dtype=bool)
    ys, xs = np.where(ridge_zone)
    for r, c in zip(ys.tolist(), xs.tolist()):
        if hash01(cfg.seed, r, c, "mtn_ridge") < float(keep_prob[r, c]):
            mtn[r, c] = True

    peak_zone = land & warm & (elev >= cfg.mountain_level) & (peaks >= cfg.peak_mountain_thresh)
    ys, xs = np.where(peak_zone & (~mtn))
    for r, c in zip(ys.tolist(), xs.tolist()):
        if hash01(cfg.seed, r, c, "mtn_peak") < cfg.mountain_peak_keep_prob:
            mtn[r, c] = True

    return thin_mountains(cfg, mtn, ridges)


def add_lakes(cfg: Config, elev: np.ndarray, land: np.ndarray, dist_to_water: np.ndarray, dist_to_mtn: np.ndarray):
    lake_n = noise_field(cfg, 80, cfg.lake_noise_scale, cfg.lake_octaves, 0)
    inland = np.clip(dist_to_water.astype(np.float32) / max(1.0, float(dist_to_water.max())), 0.0, 1.0)
    low = np.clip((cfg.sea_level + cfg.lake_level_boost - elev) / max(1e-6, cfg.lake_level_boost), 0.0, 1.0)
    near_mtn = np.exp(-dist_to_mtn.astype(np.float32) / max(1.0, float(cfg.lake_max_mtn_dist))).astype(np.float32)

    score = cfg.lake_strength * lake_n + 1.05 * low + 0.55 * inland + cfg.lake_range_bias * near_mtn
    pot = land & (dist_to_water >= cfg.lake_min_coast_dist) & (score >= cfg.lake_thresh)

    water0 = (~land) | pot
    ocean = ocean_connected_hex(water0)
    lakes = water0 & (~ocean)
    return water0, ocean, lakes


def carve_rivers(cfg: Config, elev: np.ndarray, land: np.ndarray, dist_to_water: np.ndarray, peaks: np.ndarray, ridges: np.ndarray, dist_to_mtn: np.ndarray) -> np.ndarray:
    rng = np.random.default_rng(cfg.seed + 999)
    river = np.zeros((cfg.rows, cfg.cols), dtype=np.uint8)

    valley = normalize01(1.0 - ridged01(peaks))
    candidates = np.argwhere(
        land
        & (elev >= cfg.river_source_elev)
        & (dist_to_water >= cfg.river_min_coast_dist)
        & (valley >= cfg.river_valley_thresh)
        & (ridges >= cfg.river_ridge_source_thresh)
        & (dist_to_mtn <= cfg.river_source_max_mtn_dist)
    )
    if len(candidates) == 0 or cfg.river_count <= 0:
        return river

    starts = candidates[rng.choice(len(candidates), size=min(cfg.river_count, len(candidates)), replace=False)]
    for sy, sx in starts:
        r, c = int(sy), int(sx)
        visited = set()
        for _ in range(cfg.river_max_len):
            if not land[r, c]:
                break
            river[r, c] = 1
            visited.add((r, c))

            cur_e = float(elev[r, c])
            best = None
            best_key = (1e9, -1e9)
            for rr, cc in hex_neighbors(r, c, cfg.rows, cfg.cols):
                ne = float(elev[rr, cc])
                if ne > cur_e:
                    continue
                key = (ne, -float(valley[rr, cc]))
                if key < best_key:
                    best_key = key
                    best = (rr, cc)
            if best is None:
                break
            r, c = best
            if (r, c) in visited:
                break

    return river


def prune_rivers(cfg: Config, river: np.ndarray, water: np.ndarray) -> np.ndarray:
    out = river.copy()
    rows, cols = out.shape

    def rdeg(r: int, c: int) -> int:
        return sum(1 for rr, cc in hex_neighbors(r, c, rows, cols) if out[rr, cc] == 1)

    for _ in range(max(0, int(cfg.river_prune_passes))):
        kill = []
        for r in range(rows):
            for c in range(cols):
                if out[r, c] != 1:
                    continue
                n = rdeg(r, c)
                if n == 0:
                    kill.append((r, c))
                elif n == 1:
                    if not any(water[rr, cc] for rr, cc in hex_neighbors(r, c, rows, cols)):
                        kill.append((r, c))
        if not kill:
            break
        for r, c in kill:
            out[r, c] = 0

    for r in range(rows):
        for c in range(cols):
            if out[r, c] == 1 and rdeg(r, c) == 0:
                out[r, c] = 0
    return out


def apply_ocean_depths(cfg: Config, tilemap: np.ndarray, ocean: np.ndarray, lakes: np.ndarray, dist_to_land: np.ndarray) -> np.ndarray:
    out = tilemap.copy()
    noise = water_break(cfg)
    rows, cols = out.shape
    ocean_only = ocean & (~lakes)

    out[ocean_only & (dist_to_land <= cfg.shallow_band)] = "shallow_water"
    out[ocean_only & (dist_to_land > cfg.shallow_band)] = "water"

    deep_raw = np.zeros((rows, cols), dtype=bool)
    ok = ocean_only & (dist_to_land > cfg.shallow_band)
    ys, xs = np.where(ok)
    for r, c in zip(ys.tolist(), xs.tolist()):
        if float(dist_to_land[r, c]) + float(noise[r, c]) >= float(cfg.deep_band):
            deep_raw[r, c] = True

    connect_mask = ocean_only & (dist_to_land >= (cfg.deep_band - cfg.deep_connect_relax))
    core = ocean_only & (dist_to_land >= (cfg.deep_band + cfg.deep_core_extra))

    edge = np.zeros((rows, cols), dtype=bool)
    edge[0, :] = edge[-1, :] = True
    edge[:, 0] = edge[:, -1] = True

    seeds = (core | (deep_raw & edge)) & connect_mask
    keep_zone = flood_keep(connect_mask, seeds)
    deep_keep = deep_raw & keep_zone

    band = ocean_only & (dist_to_land > cfg.shallow_band) & (dist_to_land >= cfg.deep_band - 1) & (dist_to_land <= cfg.deep_band + 2)
    ys, xs = np.where(band & (~core))
    for r, c in zip(ys.tolist(), xs.tolist()):
        n = float(noise[r, c])
        if (not deep_keep[r, c]) and (n > cfg.deep_edge_hi):
            if any(deep_keep[rr, cc] for rr, cc in hex_neighbors(r, c, rows, cols)):
                deep_keep[r, c] = True
        elif deep_keep[r, c] and (n < cfg.deep_edge_lo) and (int(dist_to_land[r, c]) <= cfg.deep_band + 1):
            deg = sum(1 for rr, cc in hex_neighbors(r, c, rows, cols) if deep_keep[rr, cc])
            if deg >= 2:
                deep_keep[r, c] = False

    out[ocean_only & (dist_to_land > cfg.shallow_band) & deep_keep] = "deep_water"
    out[lakes & (dist_to_land < 2)] = "shallow_water"
    out[lakes & (dist_to_land >= 2)] = "water"
    return out


def cluster_once(cfg: Config, tilemap: np.ndarray, mask: np.ndarray, tag: str) -> np.ndarray:
    rows, cols = tilemap.shape
    out = tilemap.copy()
    allowed = set(cfg.cluster_only)
    for r in range(rows):
        for c in range(cols):
            if not bool(mask[r, c]):
                continue
            t0 = str(tilemap[r, c])
            if t0 in cfg.cluster_protect or t0 not in allowed:
                continue
            counts = Counter()
            counts[t0] += 1
            for rr, cc in hex_neighbors(r, c, rows, cols):
                counts[str(tilemap[rr, cc])] += 1
            best_t, best_n = counts.most_common(1)[0]
            if best_t != t0 and best_n >= cfg.cluster_min_same:
                if hash01(cfg.seed, r, c, f"cl_{tag}") < cfg.cluster_change_prob:
                    out[r, c] = best_t
    return out


def cluster(cfg: Config, tilemap: np.ndarray, land_mask: np.ndarray) -> np.ndarray:
    out = tilemap
    for i in range(max(0, int(cfg.cluster_passes))):
        out = cluster_once(cfg, out, land_mask, f"land{i}")
    return out


def elevation_to_dy(cfg: Config, e_smooth: float, is_ocean: bool) -> int:
    base = e_smooth - cfg.sea_level
    if is_ocean:
        base = max(0.0, base)
    h = max(0.0, base) ** float(cfg.height_gamma)
    return int(round(-h * cfg.height_px))


def enforce_dy_limit(cfg: Config, dy: np.ndarray, ocean_only: np.ndarray) -> np.ndarray:
    rows, cols = dy.shape
    k = int(cfg.height_max_neighbor_delta)
    out = dy.astype(np.int32).copy()

    min_bound = -int(cfg.height_px * 2)
    max_bound = np.full((rows, cols), 10**9, dtype=np.int32)
    max_bound[ocean_only] = 0

    def clamp(r: int, c: int, v: int) -> int:
        if v < min_bound:
            v = min_bound
        mb = int(max_bound[r, c])
        if v > mb:
            v = mb
        return v

    for r in range(rows):
        for c in range(cols):
            out[r, c] = clamp(r, c, int(out[r, c]))

    q = deque((r, c) for r in range(rows) for c in range(cols))
    inq = np.ones((rows, cols), dtype=np.uint8)

    while q:
        r, c = q.popleft()
        inq[r, c] = 0
        a = int(out[r, c])
        for rr, cc in hex_neighbors(r, c, rows, cols):
            b = int(out[rr, cc])
            nb = b
            lo = a - k
            hi = a + k
            if nb < lo:
                nb = lo
            elif nb > hi:
                nb = hi
            nb = clamp(rr, cc, nb)
            if nb != b:
                out[rr, cc] = nb
                if inq[rr, cc] == 0:
                    inq[rr, cc] = 1
                    q.append((rr, cc))

    return out.astype(np.int32)


def build_tilemap(cfg: Config):
    elev, peaks, ridges, humid, temp, equator, land, dist_to_land, dist_to_water = build_fields(cfg)
    mtn = build_mountains(cfg, land, elev, peaks, ridges, temp)
    dist_to_mtn = hex_bfs_distance(mtn)

    water0, ocean, lakes = add_lakes(cfg, elev, land, dist_to_water, dist_to_mtn)
    land2 = ~water0
    ocean_only = ocean & (~lakes)

    river = prune_rivers(cfg, carve_rivers(cfg, elev, land2, dist_to_water, peaks, ridges, dist_to_mtn), water0)

    desert_f = noise_field(cfg, 200, cfg.desert_scale, cfg.desert_octaves, cfg.desert_smooth_passes)
    wheat_f = noise_field(cfg, 210, cfg.wheat_scale, cfg.wheat_octaves, cfg.wheat_smooth_passes)
    beach_f = noise_field(cfg, 220, cfg.beach_scale, cfg.beach_octaves, cfg.beach_smooth_passes)

    # Jungle seed field ensures clustered jungles, even when humid is patchy.
    jungle_seed = noise_field(cfg, 230, cfg.jungle_seed_scale, cfg.jungle_seed_octaves, cfg.jungle_seed_smooth)

    tilemap = np.full((cfg.rows, cfg.cols), "grass", dtype=object)

    # Rivers: shallow water paths
    tilemap[(river == 1) & land2] = "shallow_water"

    # Mountains and hills setup
    mtn2 = mtn & land2
    hills_near = hex_bfs_distance(mtn2) <= int(cfg.hill_near_mountain_dist)

    # Vectorized biome assignment (fast, less code in loops)
    r_idx = np.arange(cfg.rows, dtype=np.int32)[:, None]
    eq = equator[:, None].astype(np.float32)

    grass_min = np.maximum(0.0, cfg.grass_humid_min - cfg.equator_fields_strength * eq)
    forest_cut = cfg.forest_humid + cfg.equator_forest_suppress * eq
    hot_cut = cfg.hot_temp - 0.02 * eq

    land_mask = land2 & (tilemap != "shallow_water")
    t = temp
    h = humid
    e = elev

    # Cold
    snow = land_mask & (t <= cfg.snow_temp)
    taiga_or_dirt = land_mask & (t > cfg.snow_temp) & (t <= cfg.cold_temp)
    tilemap[snow] = "snow"
    tilemap[taiga_or_dirt & (h >= cfg.dry_humid)] = "tiaga"
    tilemap[taiga_or_dirt & (h < cfg.dry_humid)] = "dirt"

    # Mountains and hills override
    mtn_cells = land2 & mtn2
    tilemap[mtn_cells & (t <= cfg.cold_temp)] = "snow"
    tilemap[mtn_cells & (t > cfg.cold_temp)] = "mountains"

    hills = land2 & (~mtn2) & (
        ((e >= cfg.hill_level) & hills_near)
        | ((e >= (cfg.hill_level - 0.03)) & (noise_field(cfg, 900, 14, 1, 0) > 0.90))
    )
    tilemap[hills & (t <= cfg.snow_temp)] = "snow"
    tilemap[hills & (t > cfg.snow_temp)] = "hills"

    # Warm band biomes (excluding already set snow/taiga/dirt/mtn/hills/river)
    warm = land2 & (t > cfg.cold_temp) & (tilemap == "grass")

    desert_score = desert_f + (t - hot_cut) + cfg.desert_hot_boost + cfg.equator_desert_strength * eq
    desert = warm & (t >= hot_cut) & (h <= 0.44) & (desert_score > 0.90)
    tilemap[desert & (h <= cfg.very_dry_humid)] = "dunes"
    tilemap[desert & (h > cfg.very_dry_humid)] = "sand"

    # Swamps
    swamp = warm & (~desert) & (h >= cfg.wet_humid)
    ys, xs = np.where(swamp)
    for r, c in zip(ys.tolist(), xs.tolist()):
        tilemap[r, c] = swamp_variant(cfg.seed, r, c)

    # Forest base
    forest = warm & (~desert) & (~swamp) & (h >= forest_cut)
    tilemap[forest] = "forest"

    # Jungle promotion: replace some forests in very humid warm areas, in clusters
    # This is the main fix for "no jungles on most seeds".
    jungle = (
        warm
        & (h >= (cfg.jungle_humid - cfg.jungle_extra_humid_pad))
        & (t >= cfg.jungle_temp_min)
        & (jungle_seed >= cfg.jungle_seed_thresh)
        & ((tilemap == "forest") | (tilemap == "grass"))
    )
    tilemap[jungle] = "jungle"

    # Wheat
    wheat = (
        warm
        & (~desert)
        & (tilemap == "grass")
        & (0.30 <= h) & (h <= 0.64)
        & (0.34 <= t) & (t <= 0.78)
        & (wheat_f > cfg.wheat_thresh)
    )
    tilemap[wheat] = "wheat"

    # Remaining plains
    plains = warm & (tilemap == "grass")
    tilemap[plains & (h >= grass_min)] = "grass"
    tilemap[plains & (h < grass_min) & (h >= cfg.dry_humid)] = "dirt"
    tilemap[plains & (h < cfg.dry_humid)] = "clay"

    # Beaches near coasts (1 to 2 tiles)
    coast2 = land2 & (~mtn2) & (tilemap != "snow") & (tilemap != "hills") & (dist_to_water <= 2) & (t >= cfg.beach_temp_min)
    humid_mul = np.where(h >= cfg.beach_humid_cut, 0.35, 1.0).astype(np.float32)
    base_p = np.where(dist_to_water == 1, cfg.beach_base_p1, cfg.beach_base_p2).astype(np.float32)
    p = base_p * humid_mul * (0.40 + 0.60 * beach_f)
    ys, xs = np.where(coast2)
    for r, c in zip(ys.tolist(), xs.tolist()):
        if hash01(cfg.seed, r, c, "beach") < float(p[r, c]):
            tilemap[r, c] = "dunes" if (float(t[r, c]) >= cfg.hot_temp and float(h[r, c]) <= cfg.very_dry_humid) else "sand"

    # Cluster pass to remove 1 tile noise and make jungle forest fields clump
    tilemap = cluster(cfg, tilemap, land2)

    # Extra jungle clustering: a second local consolidation helps keep jungle in blobs
    tilemap = cluster_once(cfg, tilemap, land2, "jungle2")

    # Convert some grass or forest to wheat after clustering
    conv = noise_field(cfg, 400, cfg.wheat_convert_scale, cfg.wheat_convert_octaves, cfg.wheat_convert_smooth)
    ys, xs = np.where(land2 & ((tilemap == "grass") | (tilemap == "forest")))
    for r, c in zip(ys.tolist(), xs.tolist()):
        tt = float(t[r, c])
        hh = float(h[r, c])
        if not (cfg.wheat_convert_min_temp <= tt <= cfg.wheat_convert_max_temp):
            continue
        if not (cfg.wheat_convert_min_humid <= hh <= cfg.wheat_convert_max_humid):
            continue
        if float(conv[r, c]) <= 0.56:
            continue
        base = cfg.wheat_convert_prob * (1.15 if tilemap[r, c] == "grass" else 0.85)
        if hash01(cfg.seed, r, c, "wheat_conv") < base:
            tilemap[r, c] = "wheat"

    # Add some extra hills in mid elevation band
    hf = smooth_box(noise_field(cfg, 410, 10, 2, 0), 1)
    ys, xs = np.where(land2 & (tilemap != "mountains") & (tilemap != "snow") & (tilemap != "hills"))
    for r, c in zip(ys.tolist(), xs.tolist()):
        if tilemap[r, c] not in ("grass", "forest", "wheat", "jungle"):
            continue
        ee = float(e[r, c])
        if not (cfg.hill_level - 0.06 <= ee < cfg.mountain_level - 0.02):
            continue
        if float(hf[r, c]) > 0.58 and hash01(cfg.seed, r, c, "hill_add") < cfg.hill_extra_prob:
            tilemap[r, c] = "hills"

    # Ocean depths last (after clustering)
    tilemap = apply_ocean_depths(cfg, tilemap, ocean, lakes, dist_to_land)

    # Rivers override last
    tilemap[(river == 1) & land2] = "shallow_water"

    elev_smooth = smooth_box(elev, cfg.height_smooth_passes).astype(np.float32)
    return tilemap, elev_smooth, ocean_only


def render_hex_map(cfg: Config, tiles: dict[str, list[Image.Image]], tilemap: np.ndarray, elev_smooth: np.ndarray, ocean_only: np.ndarray, out_path: str) -> None:
    max_up = cfg.height_px + 28
    out_w = cfg.row_off_x + (cfg.cols - 1) * cfg.step_x + cfg.tile_w
    out_h = (cfg.rows - 1) * cfg.row_step_y + cfg.tile_h + max_up
    out = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))

    dy = np.zeros((cfg.rows, cfg.cols), dtype=np.int32)
    for r in range(cfg.rows):
        for c in range(cfg.cols):
            dy[r, c] = elevation_to_dy(cfg, float(elev_smooth[r, c]), bool(ocean_only[r, c]))

    dy = enforce_dy_limit(cfg, dy, ocean_only)

    for r in range(cfg.rows):
        base_x = cfg.row_off_x if (r % 2 == 1) else 0
        base_y = r * cfg.row_step_y + max_up
        for c in range(cfg.cols):
            out.alpha_composite(
                pick_variant(tiles, str(tilemap[r, c]), cfg.seed, r, c),
                (base_x + c * cfg.step_x, base_y + int(dy[r, c])),
            )

    out.save(out_path)
    print(f"Saved {out_path} seed={cfg.seed}")


def main() -> None:
    tiles = load_tiles("Tiles")
    tilemap, elev_smooth, ocean_only = build_tilemap(CFG)
    render_hex_map(CFG, tiles, tilemap, elev_smooth, ocean_only, "map_100x100.png")


if __name__ == "__main__":
    main()
