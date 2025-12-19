extends Node2D

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Map Settings")
@export var seed_value: int = 1
@export var map_width: int = 100
@export var map_height: int = 100

@export_group("Noise Settings")
@export var persistence: float = 0.52
@export var lacunarity: float = 2.0

@export_group("Landmass")
@export var sea_level: float = 0.44
@export var continental_scale: float = 25.0
@export var continental_octaves: int = 3
@export var continental_smooth: int = 2
@export var erosion_scale: float = 8.0
@export var erosion_octaves: int = 4
@export var erosion_strength: float = 0.55
@export var peaks_scale: float = 6.0
@export var peaks_octaves: int = 5
@export var peaks_strength: float = 0.72

@export_group("Ridge Mountains")
@export var ridge_scale_long: float = 30.0
@export var ridge_scale_short: float = 9.0
@export var ridge_octaves: int = 4
@export var ridge_strength: float = 0.55

@export_group("Mountains")
@export var mountain_level: float = 0.73
@export var ridge_mountain_thresh: float = 0.64
@export var peak_mountain_thresh: float = 0.86
@export var mountain_ridge_keep_base: float = 0.18
@export var mountain_ridge_keep_gain: float = 0.70
@export var mountain_peak_keep_prob: float = 0.28
@export var mountain_thin_passes: int = 5
@export var mountain_thin_remove_ge: int = 3

@export_group("Hills")
@export var hill_level: float = 0.65
@export var hill_near_mtn_dist: int = 3
@export var hill_extra_prob: float = 0.40

@export_group("Climate")
@export var humid_scale: float = 8.0
@export var humid_octaves: int = 5
@export var temp_scale: float = 9.0
@export var temp_octaves: int = 5
@export var warp_scale: float = 8.0
@export var warp_octaves: int = 3
@export var warp_amp: float = 4.0

@export_group("Biome Thresholds")
@export var hot_temp: float = 0.64
@export var cold_temp: float = 0.36
@export var snow_temp: float = 0.27
@export var wet_humid: float = 0.66
@export var forest_humid: float = 0.44
@export var jungle_humid: float = 0.65
@export var dry_humid: float = 0.34
@export var very_dry_humid: float = 0.22

@export_group("Jungle")
@export var jungle_temp_min: float = 0.46
@export var jungle_seed_scale: float = 5.0
@export var jungle_seed_octaves: int = 3
@export var jungle_seed_thresh: float = 0.32

@export_group("Lakes")
@export var lake_noise_scale: float = 20.0
@export var lake_octaves: int = 2
@export var lake_strength: float = 0.35
@export var lake_min_coast_dist: int = 16
@export var lake_thresh: float = 1.40
@export var lake_range_bias: float = 0.55
@export var lake_max_mtn_dist: int = 10

@export_group("Rivers")
@export var river_count: int = 6
@export var river_source_elev: float = 0.74
@export var river_min_coast_dist: int = 8
@export var river_max_len: int = 220
@export var river_prune_passes: int = 6

@export_group("Beaches")
@export var beach_scale: float = 14.0
@export var beach_octaves: int = 2
@export var beach_base_p1: float = 0.50
@export var beach_base_p2: float = 0.18
@export var beach_humid_cut: float = 0.62
@export var beach_temp_min: float = 0.30

@export_group("Wheat")
@export var wheat_scale: float = 12.0
@export var wheat_octaves: int = 2
@export var wheat_thresh: float = 0.54

@export_group("Desert")
@export var desert_scale: float = 24.0
@export var desert_octaves: int = 2
@export var desert_hot_boost: float = 0.10

@export_group("Clustering")
@export var cluster_passes: int = 2
@export var cluster_min_same: int = 4
@export var cluster_change_prob: float = 0.65

@export_group("Ocean Depth")
@export var shallow_band: int = 1
@export var deep_band: int = 3
@export var water_break_scale: float = 3.0
@export var water_break_octaves: int = 6
@export var water_break_amp: float = 5.0

# =============================================================================
# TILE MAP
# =============================================================================

@onready var tile_map: TileMapLayer = $TileMapLayer

const TILES = {
	"deep_water": [
		{"source_id": 0, "atlas_coord": Vector2i(3, 0)},
		{"source_id": 0, "atlas_coord": Vector2i(4, 0)},
	],
	"water": [
		{"source_id": 0, "atlas_coord": Vector2i(2, 8)},
		{"source_id": 0, "atlas_coord": Vector2i(3, 8)},
	],
	"shallow_water": [
		{"source_id": 0, "atlas_coord": Vector2i(4, 5)},
		{"source_id": 0, "atlas_coord": Vector2i(0, 6)},
	],
	"beach": [{"source_id": 0, "atlas_coord": Vector2i(2, 5)}],
	"sand": [{"source_id": 0, "atlas_coord": Vector2i(3, 5)}],
	"dunes": [
		{"source_id": 0, "atlas_coord": Vector2i(2, 1)},
		{"source_id": 0, "atlas_coord": Vector2i(3, 1)},
	],
	"grass": [
		{"source_id": 0, "atlas_coord": Vector2i(3, 2)},
		{"source_id": 0, "atlas_coord": Vector2i(4, 2)},
		{"source_id": 0, "atlas_coord": Vector2i(0, 3)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 3)},
	],
	"forest": [
		{"source_id": 0, "atlas_coord": Vector2i(4, 1)},
		{"source_id": 0, "atlas_coord": Vector2i(0, 2)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 2)},
		{"source_id": 0, "atlas_coord": Vector2i(2, 2)},
	],
	"jungle": [
		{"source_id": 0, "atlas_coord": Vector2i(4, 3)},
		{"source_id": 0, "atlas_coord": Vector2i(0, 4)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 4)},
		{"source_id": 0, "atlas_coord": Vector2i(2, 4)},
	],
	"dirt": [
		{"source_id": 0, "atlas_coord": Vector2i(0, 1)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 1)},
	],
	"clay": [
		{"source_id": 0, "atlas_coord": Vector2i(0, 0)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 0)},
		{"source_id": 0, "atlas_coord": Vector2i(2, 0)},
	],
	"hills": [
		{"source_id": 0, "atlas_coord": Vector2i(2, 3)},
		{"source_id": 0, "atlas_coord": Vector2i(3, 3)},
	],
	"mountains": [
		{"source_id": 0, "atlas_coord": Vector2i(3, 4)},
		{"source_id": 0, "atlas_coord": Vector2i(4, 4)},
	],
	"snow": [
		{"source_id": 0, "atlas_coord": Vector2i(1, 6)},
		{"source_id": 0, "atlas_coord": Vector2i(2, 6)},
	],
	"swamp": [
		{"source_id": 0, "atlas_coord": Vector2i(2, 7)},
		{"source_id": 0, "atlas_coord": Vector2i(3, 7)},
	],
	"swamp_pads": [
		{"source_id": 0, "atlas_coord": Vector2i(3, 6)},
		{"source_id": 0, "atlas_coord": Vector2i(4, 6)},
	],
	"swamp_reeds": [
		{"source_id": 0, "atlas_coord": Vector2i(0, 7)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 7)},
	],
	"tiaga": [
		{"source_id": 0, "atlas_coord": Vector2i(4, 7)},
		{"source_id": 0, "atlas_coord": Vector2i(0, 8)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 8)},
	],
	"wheat": [
		{"source_id": 0, "atlas_coord": Vector2i(4, 8)},
		{"source_id": 0, "atlas_coord": Vector2i(0, 9)},
		{"source_id": 0, "atlas_coord": Vector2i(1, 9)},
		{"source_id": 0, "atlas_coord": Vector2i(2, 9)},
	],
}

const CLUSTER_PROTECT = ["deep_water", "water", "shallow_water", "mountains", "snow"]
const CLUSTER_ONLY = ["grass", "forest", "jungle", "wheat", "swamp", "swamp_pads", "swamp_reeds", "dirt", "clay", "sand", "dunes", "tiaga"]

# =============================================================================
# RUNTIME STATE
# =============================================================================

var _rng: RandomNumberGenerator

# Data arrays (2D indexed as [y][x])
var _elev: Array = []
var _peaks: Array = []
var _ridges: Array = []
var _humid: Array = []
var _temp: Array = []
var _equator: Array = []
var _land: Array = []
var _dist_to_land: Array = []
var _dist_to_water: Array = []
var _dist_to_mtn: Array = []
var _mtn: Array = []
var _lakes: Array = []
var _ocean: Array = []
var _rivers: Array = []
var _tiles: Array = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	var camera = CameraController.new()
	camera.zoom = Vector2(camera.min_zoom, camera.min_zoom)
	add_child(camera)
	generate_new_map()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		seed_value += 1
		generate_new_map()

# =============================================================================
# MAIN GENERATION
# =============================================================================

func generate_new_map() -> void:
	print("Generating Map... Seed: ", seed_value)
	tile_map.clear()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	
	_init_arrays()
	_build_fields()
	_build_mountains()
	_add_lakes()
	_carve_rivers()
	_assign_biomes()
	_apply_beaches()
	_cluster_biomes()
	_apply_ocean_depths()
	_rivers_override()
	_render_tiles()
	
	print("Map generation complete!")

func _init_arrays() -> void:
	_elev = _make_2d_array(0.0)
	_peaks = _make_2d_array(0.0)
	_ridges = _make_2d_array(0.0)
	_humid = _make_2d_array(0.0)
	_temp = _make_2d_array(0.0)
	_equator = _make_2d_array(0.0)
	_land = _make_2d_array(false)
	_dist_to_land = _make_2d_array(999999)
	_dist_to_water = _make_2d_array(999999)
	_dist_to_mtn = _make_2d_array(999999)
	_mtn = _make_2d_array(false)
	_lakes = _make_2d_array(false)
	_ocean = _make_2d_array(false)
	_rivers = _make_2d_array(false)
	_tiles = _make_2d_array("grass")

func _make_2d_array(default_val) -> Array:
	var arr = []
	for _y in range(map_height):
		var row = []
		row.resize(map_width)
		row.fill(default_val)
		arr.append(row)
	return arr

# =============================================================================
# FIELD GENERATION (build_fields from Python)
# =============================================================================

func _build_fields() -> void:
	# Noise generators
	var noise_cont = _create_noise(seed_value + 10, continental_scale, continental_octaves)
	var noise_peaks = _create_noise(seed_value + 20, peaks_scale, peaks_octaves)
	var noise_erosion = _create_noise(seed_value + 30, erosion_scale, erosion_octaves)
	var noise_ridge_a = _create_noise_aniso(seed_value + 25, ridge_scale_short, ridge_scale_long, ridge_octaves)
	var noise_ridge_b = _create_noise_aniso(seed_value + 26, ridge_scale_long, ridge_scale_short, ridge_octaves)
	var noise_humid = _create_noise(seed_value + 40, humid_scale, humid_octaves)
	var noise_temp = _create_noise(seed_value + 50, temp_scale, temp_octaves)
	var noise_warp_x = _create_noise(seed_value + 71, warp_scale, warp_octaves)
	var noise_warp_y = _create_noise(seed_value + 72, warp_scale, warp_octaves)
	
	# =========================================================================
	# PASS 1: Compute RAW elevation (not normalized yet), peaks, ridges, humidity
	# =========================================================================
	var raw_elev = _make_2d_array(0.0)
	
	for y in range(map_height):
		var lat = float(y) / float(map_height)
		var eq = 1.0 - abs(lat * 2.0 - 1.0)
		
		for x in range(map_width):
			_equator[y][x] = eq
			
			# Domain warp offsets
			var wx = int((noise_warp_x.get_noise_2d(x, y)) * warp_amp)
			var wy = int((noise_warp_y.get_noise_2d(x, y)) * warp_amp)
			var warped_x = clampi(x + wx, 0, map_width - 1)
			var warped_y = clampi(y + wy, 0, map_height - 1)
			
			# Continental (smooth) - rescale to favor land masses
			var cont = (noise_cont.get_noise_2d(x, y) + 1.0) * 0.5
			cont = clamp((cont - 0.22) / 0.78, 0.0, 1.0)
			
			# Peaks (ridged)
			var peak_raw = (noise_peaks.get_noise_2d(x, y) + 1.0) * 0.5
			var peak_ridged = _ridged01(peak_raw)
			
			# Erosion
			var ero = (noise_erosion.get_noise_2d(x, y) + 1.0) * 0.5
			
			# Ridges (anisotropic, max of two)
			var ridge_a = _ridged01((noise_ridge_a.get_noise_2d(x, y) + 1.0) * 0.5)
			var ridge_b = _ridged01((noise_ridge_b.get_noise_2d(x, y) + 1.0) * 0.5)
			var ridge = max(ridge_a, ridge_b)
			
			# RAW elevation composition (will normalize later!)
			var peaks2 = peak_ridged * (1.0 - erosion_strength * ero)
			var elev_raw = cont + peaks_strength * peaks2 + ridge_strength * ridge
			
			raw_elev[y][x] = elev_raw
			_peaks[y][x] = peak_ridged
			_ridges[y][x] = ridge
			
			# Humidity (warped)
			var hum = (noise_humid.get_noise_2d(warped_x, warped_y) + 1.0) * 0.5
			_humid[y][x] = hum
	
	# =========================================================================
	# PASS 2: Normalize elevation to 0-1 range (like Python's normalize01)
	# =========================================================================
	var elev_min = raw_elev[0][0]
	var elev_max = raw_elev[0][0]
	for y in range(map_height):
		for x in range(map_width):
			var v = raw_elev[y][x]
			if v < elev_min: elev_min = v
			if v > elev_max: elev_max = v
	
	var elev_range = elev_max - elev_min
	if elev_range < 0.0001:
		elev_range = 1.0
	
	for y in range(map_height):
		for x in range(map_width):
			_elev[y][x] = (raw_elev[y][x] - elev_min) / elev_range
	
	# Smooth elevation (box blur)
	_elev = _smooth_box(_elev, continental_smooth)
	_ridges = _smooth_box(_ridges, 1)
	
	# =========================================================================
	# PASS 3: Compute land mask and temperature (depends on normalized elevation)
	# =========================================================================
	for y in range(map_height):
		for x in range(map_width):
			var elev = _elev[y][x]
			var eq = _equator[y][x]
			
			# Land mask
			_land[y][x] = elev >= sea_level
			
			# Temperature (latitude + elevation cooling)
			var wx = int((noise_warp_x.get_noise_2d(x, y)) * warp_amp)
			var wy = int((noise_warp_y.get_noise_2d(x, y)) * warp_amp)
			var warped_x = clampi(x + wx, 0, map_width - 1)
			var warped_y = clampi(y + wy, 0, map_height - 1)
			var tmp_raw = (noise_temp.get_noise_2d(warped_x, warped_y) + 1.0) * 0.5
			var temp = 0.7 * eq + 0.3 * tmp_raw
			temp -= 0.38 * max(elev - sea_level, 0.0)
			temp = clamp(temp, 0.0, 1.0)
			_temp[y][x] = temp
	
	# Compute distances
	_dist_to_land = _hex_bfs_distance(_land, true)
	_dist_to_water = _hex_bfs_distance(_land, false)
	
	# Water influence on humidity
	for y in range(map_height):
		for x in range(map_width):
			var water_inf = exp(-float(_dist_to_water[y][x]) / 3.2)
			_humid[y][x] = 0.70 * _humid[y][x] + 0.30 * water_inf
			_humid[y][x] = clamp(_humid[y][x], 0.0, 1.0)

# =============================================================================
# MOUNTAINS (build_mountains + thin_mountains from Python)
# =============================================================================

func _build_mountains() -> void:
	# Ridge-based mountains
	for y in range(map_height):
		for x in range(map_width):
			if not _land[y][x]: continue
			if _temp[y][x] <= cold_temp: continue # Only warm areas
			
			var e = _elev[y][x]
			var r = _ridges[y][x]
			
			# Ridge zone
			if e >= (mountain_level - 0.06) and r >= ridge_mountain_thresh:
				var rr = clamp((r - ridge_mountain_thresh) / max(0.001, 1.0 - ridge_mountain_thresh), 0.0, 1.0)
				var keep_prob = clamp(mountain_ridge_keep_base + mountain_ridge_keep_gain * rr, 0.0, 1.0)
				if _hash01(y, x, "mtn_ridge") < keep_prob:
					_mtn[y][x] = true
			
			# Peak zone
			if e >= mountain_level and _peaks[y][x] >= peak_mountain_thresh:
				if not _mtn[y][x] and _hash01(y, x, "mtn_peak") < mountain_peak_keep_prob:
					_mtn[y][x] = true
	
	# Thin mountains (remove overconnected, isolated)
	for _p in range(mountain_thin_passes):
		var to_remove = []
		for y in range(map_height):
			for x in range(map_width):
				if not _mtn[y][x]: continue
				var n = _count_neighbors(_mtn, x, y)
				if n >= mountain_thin_remove_ge:
					if _ridges[y][x] < 0.84:
						to_remove.append(Vector2i(x, y))
				elif n == 0:
					to_remove.append(Vector2i(x, y))
		for pos in to_remove:
			_mtn[pos.y][pos.x] = false
	
	# Prune specks
	_prune_specks(_mtn, "mtn", 2)
	
	# Compute distance to mountains
	_dist_to_mtn = _hex_bfs_distance(_mtn, true)

# =============================================================================
# LAKES (add_lakes from Python)
# =============================================================================

func _add_lakes() -> void:
	var noise_lake = _create_noise(seed_value + 80, lake_noise_scale, lake_octaves)
	
	# Score each land cell for lake potential
	var max_dist = float(max(_dist_to_water[0][0], 1))
	for y in range(map_height):
		for x in range(map_width):
			if _dist_to_water[y][x] > max_dist:
				max_dist = float(_dist_to_water[y][x])
	
	var lake_potential = _make_2d_array(false)
	
	for y in range(map_height):
		for x in range(map_width):
			if not _land[y][x]: continue
			if _dist_to_water[y][x] < lake_min_coast_dist: continue
			
			var lake_n = (noise_lake.get_noise_2d(x, y) + 1.0) * 0.5
			var inland = clamp(float(_dist_to_water[y][x]) / max_dist, 0.0, 1.0)
			var low = clamp((sea_level + 0.05 - _elev[y][x]) / 0.05, 0.0, 1.0)
			var near_mtn = exp(-float(_dist_to_mtn[y][x]) / float(max(1, lake_max_mtn_dist)))
			
			var score = lake_strength * lake_n + 1.05 * low + 0.55 * inland + lake_range_bias * near_mtn
			if score >= lake_thresh:
				lake_potential[y][x] = true
	
	# Create water mask including lakes
	var water_mask = _make_2d_array(false)
	for y in range(map_height):
		for x in range(map_width):
			water_mask[y][x] = (not _land[y][x]) or lake_potential[y][x]
	
	# Find ocean (connected to edges)
	_ocean = _flood_from_edges(water_mask)
	
	# Lakes are water not connected to ocean
	for y in range(map_height):
		for x in range(map_width):
			_lakes[y][x] = water_mask[y][x] and not _ocean[y][x]
			# Update land mask
			if _lakes[y][x]:
				_land[y][x] = false

# =============================================================================
# RIVERS (carve_rivers + prune_rivers from Python)
# =============================================================================

func _carve_rivers() -> void:
	var candidates = []
	
	# Find river source candidates
	for y in range(map_height):
		for x in range(map_width):
			if not _land[y][x]: continue
			if _elev[y][x] < river_source_elev: continue
			if _dist_to_water[y][x] < river_min_coast_dist: continue
			if _dist_to_mtn[y][x] > 10: continue
			candidates.append(Vector2i(x, y))
	
	if candidates.is_empty() or river_count <= 0:
		return
	
	# Randomly select starting points
	candidates.shuffle()
	var starts = candidates.slice(0, min(river_count, candidates.size()))
	
	# Carve each river
	for start in starts:
		var cur = start
		var visited = {}
		
		for _step in range(river_max_len):
			if not _land[cur.y][cur.x]:
				break
			_rivers[cur.y][cur.x] = true
			visited[cur] = true
			
			var cur_e = _elev[cur.y][cur.x]
			var best: Variant = null
			var best_e = cur_e
			
			for n in _hex_neighbors(cur.x, cur.y):
				if n in visited: continue
				var ne = _elev[n.y][n.x]
				if ne < best_e:
					best_e = ne
					best = n
			
			if best == null:
				break
			cur = best
	
	# Prune short river segments
	for _p in range(river_prune_passes):
		var to_remove = []
		for y in range(map_height):
			for x in range(map_width):
				if not _rivers[y][x]: continue
				var n = _count_neighbors(_rivers, x, y)
				if n == 0:
					to_remove.append(Vector2i(x, y))
				elif n == 1:
					# Check if touching water
					var touches_water = false
					for nb in _hex_neighbors(x, y):
						if not _land[nb.y][nb.x] or _lakes[nb.y][nb.x]:
							touches_water = true
							break
					if not touches_water:
						to_remove.append(Vector2i(x, y))
		for pos in to_remove:
			_rivers[pos.y][pos.x] = false

# =============================================================================
# BIOME ASSIGNMENT
# =============================================================================

func _assign_biomes() -> void:
	var noise_desert = _create_noise(seed_value + 200, desert_scale, desert_octaves)
	var noise_wheat = _create_noise(seed_value + 210, wheat_scale, wheat_octaves)
	var noise_jungle = _create_noise(seed_value + 230, jungle_seed_scale, jungle_seed_octaves)
	
	for y in range(map_height):
		for x in range(map_width):
			var tile = "grass"
			var e = _elev[y][x]
			var t = _temp[y][x]
			var h = _humid[y][x]
			var eq = _equator[y][x]
			
			# Water
			if not _land[y][x]:
				if _lakes[y][x]:
					tile = "shallow_water"
				else:
					tile = "water" # Ocean depths applied later
				_tiles[y][x] = tile
				continue
			
			# Rivers (treated as shallow water for now)
			if _rivers[y][x]:
				_tiles[y][x] = "shallow_water"
				continue
			
			# Mountains
			if _mtn[y][x]:
				tile = "snow" if t <= cold_temp else "mountains"
				_tiles[y][x] = tile
				continue
			
			# Hills
			var is_hill = false
			if e >= hill_level:
				if _dist_to_mtn[y][x] <= hill_near_mtn_dist:
					is_hill = true
				elif _hash01(y, x, "hill") < hill_extra_prob:
					is_hill = true
			
			if is_hill:
				tile = "snow" if t <= snow_temp else "hills"
				_tiles[y][x] = tile
				continue
			
			# Cold biomes
			if t <= snow_temp:
				tile = "snow"
			elif t <= cold_temp:
				tile = "tiaga" if h >= dry_humid else "dirt"
			else:
				# Warm biomes
				var hot_cut = hot_temp - 0.02 * eq
				var forest_cut = forest_humid + 0.06 * eq
				var grass_min = max(0.0, 0.36 - 0.14 * eq)
				
				# Desert
				var desert_n = (noise_desert.get_noise_2d(x, y) + 1.0) * 0.5
				var desert_score = desert_n + (t - hot_cut) + desert_hot_boost + 0.10 * eq
				if t >= hot_cut and h <= 0.44 and desert_score > 0.90:
					tile = "dunes" if h <= very_dry_humid else "sand"
				# Swamp
				elif h >= wet_humid:
					var sv = _hash01(y, x, "swamp")
					if sv < 0.33:
						tile = "swamp"
					elif sv < 0.66:
						tile = "swamp_pads"
					else:
						tile = "swamp_reeds"
				# Jungle
				elif h >= (jungle_humid - 0.04) and t >= jungle_temp_min:
					var jungle_n = (noise_jungle.get_noise_2d(x, y) + 1.0) * 0.5
					if jungle_n >= jungle_seed_thresh:
						tile = "jungle"
					elif h >= forest_cut:
						tile = "forest"
					else:
						tile = "grass"
				# Forest
				elif h >= forest_cut:
					tile = "forest"
				# Wheat
				elif h >= 0.30 and h <= 0.64 and t >= 0.34 and t <= 0.78:
					var wheat_n = (noise_wheat.get_noise_2d(x, y) + 1.0) * 0.5
					if wheat_n > wheat_thresh:
						tile = "wheat"
					elif h >= grass_min:
						tile = "grass"
					else:
						tile = "dirt"
				# Plains
				elif h >= grass_min:
					tile = "grass"
				elif h >= dry_humid:
					tile = "dirt"
				else:
					tile = "clay"
			
			_tiles[y][x] = tile

# =============================================================================
# BEACHES
# =============================================================================

func _apply_beaches() -> void:
	var noise_beach = _create_noise(seed_value + 220, beach_scale, beach_octaves)
	
	for y in range(map_height):
		for x in range(map_width):
			if not _land[y][x]: continue
			if _mtn[y][x]: continue
			if _tiles[y][x] in ["snow", "hills"]: continue
			if _dist_to_water[y][x] > 2: continue
			if _temp[y][x] < beach_temp_min: continue
			
			var h = _humid[y][x]
			var humid_mul = 0.35 if h >= beach_humid_cut else 1.0
			var base_p = beach_base_p1 if _dist_to_water[y][x] == 1 else beach_base_p2
			var beach_n = (noise_beach.get_noise_2d(x, y) + 1.0) * 0.5
			var p = base_p * humid_mul * (0.40 + 0.60 * beach_n)
			
			if _hash01(y, x, "beach") < p:
				if _temp[y][x] >= hot_temp and h <= very_dry_humid:
					_tiles[y][x] = "dunes"
				else:
					_tiles[y][x] = "sand"

# =============================================================================
# CLUSTERING (smooth biomes)
# =============================================================================

func _cluster_biomes() -> void:
	for _p in range(cluster_passes):
		_cluster_once("land" + str(_p))
	_cluster_once("jungle2") # Extra jungle clustering

func _cluster_once(tag: String) -> void:
	var new_tiles = []
	for y in range(map_height):
		var row = []
		for x in range(map_width):
			row.append(_tiles[y][x])
		new_tiles.append(row)
	
	for y in range(map_height):
		for x in range(map_width):
			if not _land[y][x]: continue
			var t0 = _tiles[y][x]
			if t0 in CLUSTER_PROTECT: continue
			if not t0 in CLUSTER_ONLY: continue
			
			var counts = {t0: 1}
			for n in _hex_neighbors(x, y):
				var nt = _tiles[n.y][n.x]
				counts[nt] = counts.get(nt, 0) + 1
			
			var best_t = t0
			var best_n = 1
			for t in counts:
				if counts[t] > best_n:
					best_n = counts[t]
					best_t = t
			
			if best_t != t0 and best_n >= cluster_min_same:
				if _hash01(y, x, "cl_" + tag) < cluster_change_prob:
					new_tiles[y][x] = best_t
	
	_tiles = new_tiles

# =============================================================================
# OCEAN DEPTHS
# =============================================================================

func _apply_ocean_depths() -> void:
	var noise_break = _create_noise(seed_value + 310, water_break_scale, water_break_octaves)
	
	for y in range(map_height):
		for x in range(map_width):
			if _land[y][x]: continue
			if _lakes[y][x]:
				_tiles[y][x] = "shallow_water" if _dist_to_land[y][x] < 2 else "water"
				continue
			
			# Ocean
			var dist = _dist_to_land[y][x]
			var noise_val = noise_break.get_noise_2d(x, y) * water_break_amp
			
			if dist <= shallow_band:
				_tiles[y][x] = "shallow_water"
			elif dist + noise_val >= deep_band:
				_tiles[y][x] = "deep_water"
			else:
				_tiles[y][x] = "water"

# =============================================================================
# RIVERS OVERRIDE (final pass)
# =============================================================================

func _rivers_override() -> void:
	for y in range(map_height):
		for x in range(map_width):
			if _rivers[y][x] and _land[y][x]:
				_tiles[y][x] = "shallow_water"

# =============================================================================
# RENDER TILES
# =============================================================================

func _render_tiles() -> void:
	for y in range(map_height):
		for x in range(map_width):
			_set_cell(x, y, _tiles[y][x])

func _set_cell(x: int, y: int, tile_type: String) -> void:
	if not tile_type in TILES:
		print_debug("Unknown tile type: ", tile_type)
		return
	
	var variants = TILES[tile_type]
	var variant = variants[_rng.randi() % variants.size()]
	tile_map.set_cell(Vector2i(x, y), variant.source_id, variant.atlas_coord)

# =============================================================================
# NOISE HELPERS
# =============================================================================

func _create_noise(seed_n: int, period: float, octaves: int) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_n
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / period
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = persistence
	return noise

func _create_noise_aniso(seed_n: int, scale_x: float, scale_y: float, octaves: int) -> FastNoiseLite:
	# Godot's FastNoiseLite doesn't support anisotropic noise directly,
	# so we simulate by scaling coordinates during sampling.
	# For now, use average scale.
	var avg_scale = (scale_x + scale_y) / 2.0
	return _create_noise(seed_n, avg_scale, octaves)

func _ridged01(val: float) -> float:
	return 1.0 - abs(2.0 * val - 1.0)

# =============================================================================
# UTILITY HELPERS
# =============================================================================

func _hash01(r: int, c: int, tag: String) -> float:
	var h = hash(str(seed_value) + "|" + tag + "|" + str(r) + "|" + str(c))
	return float(h & 0x7FFFFFFF) / float(0x7FFFFFFF)

func _hex_neighbors(x: int, y: int) -> Array:
	var deltas: Array
	if y % 2 == 0:
		deltas = [
			Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, -1), Vector2i(-1, 0),
			Vector2i(1, -1), Vector2i(1, 0)
		]
	else:
		deltas = [
			Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(-1, 1),
			Vector2i(1, 0), Vector2i(1, 1)
		]
	
	var neighbors = []
	for d in deltas:
		var nx = x + d.x
		var ny = y + d.y
		if nx >= 0 and nx < map_width and ny >= 0 and ny < map_height:
			neighbors.append(Vector2i(nx, ny))
	return neighbors

func _count_neighbors(mask: Array, x: int, y: int) -> int:
	var count = 0
	for n in _hex_neighbors(x, y):
		if mask[n.y][n.x]:
			count += 1
	return count

func _hex_bfs_distance(mask: Array, find_in_mask: bool) -> Array:
	var dist = _make_2d_array(999999)
	var queue = []
	
	for y in range(map_height):
		for x in range(map_width):
			var in_mask = mask[y][x]
			if (find_in_mask and in_mask) or (not find_in_mask and not in_mask):
				dist[y][x] = 0
				queue.append(Vector2i(x, y))
	
	var head = 0
	while head < queue.size():
		var cur = queue[head]
		head += 1
		var nd = dist[cur.y][cur.x] + 1
		for n in _hex_neighbors(cur.x, cur.y):
			if nd < dist[n.y][n.x]:
				dist[n.y][n.x] = nd
				queue.append(n)
	
	return dist

func _smooth_box(data: Array, passes: int) -> Array:
	var result = data.duplicate(true)
	for _p in range(passes):
		var new_result = _make_2d_array(0.0)
		for y in range(map_height):
			for x in range(map_width):
				var total = result[y][x]
				var count = 1
				for n in _hex_neighbors(x, y):
					total += result[n.y][n.x]
					count += 1
				new_result[y][x] = total / float(count)
		result = new_result
	return result

func _flood_from_edges(mask: Array) -> Array:
	var flooded = _make_2d_array(false)
	var queue = []
	
	# Start from edges
	for x in range(map_width):
		if mask[0][x] and not flooded[0][x]:
			flooded[0][x] = true
			queue.append(Vector2i(x, 0))
		if mask[map_height - 1][x] and not flooded[map_height - 1][x]:
			flooded[map_height - 1][x] = true
			queue.append(Vector2i(x, map_height - 1))
	for y in range(map_height):
		if mask[y][0] and not flooded[y][0]:
			flooded[y][0] = true
			queue.append(Vector2i(0, y))
		if mask[y][map_width - 1] and not flooded[y][map_width - 1]:
			flooded[y][map_width - 1] = true
			queue.append(Vector2i(map_width - 1, y))
	
	var head = 0
	while head < queue.size():
		var cur = queue[head]
		head += 1
		for n in _hex_neighbors(cur.x, cur.y):
			if mask[n.y][n.x] and not flooded[n.y][n.x]:
				flooded[n.y][n.x] = true
				queue.append(n)
	
	return flooded

func _prune_specks(mask: Array, tag: String, passes: int) -> void:
	for _p in range(passes):
		var to_remove = []
		for y in range(map_height):
			for x in range(map_width):
				if not mask[y][x]: continue
				var n = _count_neighbors(mask, x, y)
				if n == 0:
					to_remove.append(Vector2i(x, y))
				elif n == 1 and _hash01(y, x, tag + "_prune") < 0.70:
					to_remove.append(Vector2i(x, y))
		for pos in to_remove:
			mask[pos.y][pos.x] = false
