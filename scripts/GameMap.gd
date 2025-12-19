extends Node2D

# --- Config ---
@export_group("Map Settings")
@export var seed_value: int = 1
@export var map_width: int = 100
@export var map_height: int = 100

@export_group("Noise Settings")
@export var persistence: float = 0.52
@export var lacunarity: float = 2.0
@export var warp_scale: float = 8.0
@export var warp_amp: float = 4.0

@export_group("Landmass")
@export var sea_level: float = 0.44
@export var continental_scale: float = 25.0
@export var erosion_scale: float = 8.0
@export var erosion_strength: float = 0.55
@export var peaks_scale: float = 6.0
@export var peaks_strength: float = 0.72

@export_group("Climate")
@export var humid_scale: float = 8.0
@export var temp_scale: float = 9.0
@export var desert_scale: float = 24.0

@export_group("Features")
@export var river_count: int = 6
@export var lake_strength: float = 0.35

# --- TileMap ---
@onready var tile_map: TileMapLayer = $TileMapLayer

# Atlas Coords for the TileSet (Estimated from user request and typical layouts)
# User mentioned: assets/map/terrain/pixel_tiles_terrain.png
# Format: "name": [{source_id, atlas_coord}, ...]
const TILES = {
	"deep_water": [{"source_id": 0, "atlas_coord": Vector2i(3, 0)}],
	"water": [{"source_id": 0, "atlas_coord": Vector2i(2, 8)}],
	"shallow_water": [{"source_id": 0, "atlas_coord": Vector2i(4, 5)}],
	
	"beach": [{"source_id": 0, "atlas_coord": Vector2i(2, 5)}],
	"sand": [{"source_id": 0, "atlas_coord": Vector2i(3, 5)}],
	"dunes": [{"source_id": 0, "atlas_coord": Vector2i(2, 1)}],

	"grass": [{"source_id": 0, "atlas_coord": Vector2i(1, 3)}],
	"forest": [{"source_id": 0, "atlas_coord": Vector2i(0, 2)}],
	"jungle": [{"source_id": 0, "atlas_coord": Vector2i(4, 3)}],
	
	"dirt": [{"source_id": 0, "atlas_coord": Vector2i(0, 1)}],
	"clay": [{"source_id": 0, "atlas_coord": Vector2i(1, 0)}],
	
	"hills": [{"source_id": 0, "atlas_coord": Vector2i(2, 3)}],
	"mountains": [{"source_id": 0, "atlas_coord": Vector2i(3, 4)}],
	"snow": [{"source_id": 0, "atlas_coord": Vector2i(1, 6)}],
	
	"swamp": [{"source_id": 0, "atlas_coord": Vector2i(2, 7)}],
	"swamp_pads": [{"source_id": 0, "atlas_coord": Vector2i(3, 6)}],
	"swamp_reeds": [{"source_id": 0, "atlas_coord": Vector2i(0, 7)}],
	
	"tiaga": [{"source_id": 0, "atlas_coord": Vector2i(1, 8)}], # Assuming cold forest
	"wheat": [{"source_id": 0, "atlas_coord": Vector2i(4, 8)}],
}

var _rng: RandomNumberGenerator

func _ready() -> void:
	# Setup Camera
	var camera = CameraController.new()
	camera.zoom = Vector2(0.2, 0.2)
	add_child(camera)
		
	generate_new_map()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		seed_value += 1
		generate_new_map()

func generate_new_map() -> void:
	print("Generating Map... Seed: ", seed_value)
	tile_map.clear()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	
	# 1. Prepare Noise Generatores
	var noise_cont = _create_noise(seed_value + 10, continental_scale)
	var noise_peaks = _create_noise(seed_value + 20, peaks_scale)
	var noise_erosion = _create_noise(seed_value + 30, erosion_scale)
	var noise_humid = _create_noise(seed_value + 40, humid_scale)
	var noise_temp = _create_noise(seed_value + 50, temp_scale)
	
	var data_elev = []
	var data_humid = []
	var data_temp = []
	
	# 2. Main Generation Loop (Per Hex)
	# Note: GDScript Loop can be slow for very large maps, keep size reasonable for prototype
	for y in range(map_height):
		var row_elev = []
		var row_humid = []
		var row_temp = []
		for x in range(map_width):
			# Hex Coordinate Offset
			# No complex warping for now to keep it simple, added basic noise composition
			
			var nx = x
			var ny = y
			
			# Elevation
			var base = (noise_cont.get_noise_2d(nx, ny) + 1.0) * 0.5 # 0-1
			var peaks = abs(noise_peaks.get_noise_2d(nx, ny)) # ridge-like
			var ero = (noise_erosion.get_noise_2d(nx, ny) + 1.0) * 0.5
			
			# Python Line 514: elev = normalize01(cont + cfg.peaks_strength * peaks2 + cfg.ridge_strength * ridges)
			# Simplified Port:
			var h = base + (peaks_strength * peaks * (1.0 - erosion_strength * ero))
			h = clamp(h, 0.0, 1.0)
			
			# Humidity & Temp
			var hum = (noise_humid.get_noise_2d(nx, ny) + 1.0) * 0.5
			var tmp_raw = (noise_temp.get_noise_2d(nx, ny) + 1.0) * 0.5
			
			# Latitude effect (equator is hotter)
			var lat = float(y) / float(map_height)
			var equator = 1.0 - abs(lat * 2.0 - 1.0)
			var temp = 0.7 * equator + 0.3 * tmp_raw
			
			# Height cools temp
			temp -= 0.38 * max(h - sea_level, 0.0)
			temp = clamp(temp, 0.0, 1.0)
			
			# Water accumulation effect (approx)
			if h < sea_level:
				hum += 0.3
			hum = clamp(hum, 0.0, 1.0)

			row_elev.append(h)
			row_humid.append(hum)
			row_temp.append(temp)
			
			# Note: We place tiles LATER after rivers are calculated
			
		data_elev.append(row_elev)
		data_humid.append(row_humid)
		data_temp.append(row_temp)
		
	# 3. Rivers
	var rivers = _carve_rivers(data_elev, data_humid)
	
	# 4. Final Placement
	for y in range(map_height):
		for x in range(map_width):
			var h = data_elev[y][x]
			var t = data_temp[y][x]
			var m = data_humid[y][x]
			var is_river = rivers.has(Vector2i(x,y))
			
			_place_tile(x, y, h, t, m, is_river)

func _carve_rivers(elev_map: Array, humid_map: Array) -> Dictionary:
	var rivers = {} # Vector2i -> bool
	var attempts = 0
	var created_rivers = 0
	
	while created_rivers < river_count and attempts < river_count * 10:
		attempts += 1
		# Random Start Point
		var start_x = _rng.randi_range(0, map_width - 1)
		var start_y = _rng.randi_range(0, map_height - 1)
		
		# Check Criteria (High enough, humid enough)
		var h = elev_map[start_y][start_x]
		var m = humid_map[start_y][start_x]
		
		if h < sea_level or h < 0.6: continue # Must be high ground
		if m < 0.4: continue # Must be somewhat wet
		
		# Walk Downhill
		var curs = Vector2i(start_x, start_y)
		var path = []
		var _reached_water = false
		
		for step in range(100): # Max Length
			path.append(curs)
			
			if elev_map[curs.y][curs.x] < sea_level:
				_reached_water = true
				break
				
			# Find lowest neighbor
			var lowest = curs
			var lowest_h = elev_map[curs.y][curs.x]
			
			# Hex Neighbors (Odd-r offset)
			var deltas = []
			if curs.y % 2 == 0:
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
			
			for d in deltas:
				var n = curs + d
				if n.x < 0 or n.x >= map_width or n.y < 0 or n.y >= map_height: continue
				var nh = elev_map[n.y][n.x]
				if nh < lowest_h:
					lowest_h = nh
					lowest = n
			
			if lowest == curs:
				# Local minimum (lake potential)
				break
			
			curs = lowest
		
		if path.size() > 5:
			for p in path:
				rivers[p] = true
			created_rivers += 1
			
	return rivers

func _place_tile(x: int, y: int, h: float, t: float, m: float, is_river: bool) -> void:
	var tile_type = "grass"
	
	if h < sea_level:
		if h < sea_level - 0.25:
			tile_type = "deep_water"
		elif h < sea_level - 0.05:
			tile_type = "water"
		else:
			tile_type = "shallow_water"
	else:
		if is_river:
			tile_type = "shallow_water" # Use shallow water for rivers for now
		# Land Logic (Whittaker-like)
		elif h > 0.85:
			tile_type = "mountains"
		elif h > 0.75:
			tile_type = "hills"
		else:
			# Biome Chart
			if t < 0.2:
				tile_type = "snow"
			elif t < 0.4:
				if m < 0.3: tile_type = "tiaga" # or tundra
				else: tile_type = "snow"
			elif t > 0.7:
				if m < 0.3: tile_type = "dunes" # Desert
				elif m < 0.5: tile_type = "sand"
				elif m > 0.8: tile_type = "jungle"
				else: tile_type = "grass"
			else:
				# Temperate
				if m < 0.3: tile_type = "dirt"
				elif m > 0.7: tile_type = "forest"
				else: tile_type = "grass"
				
	_set_cell(x, y, tile_type)

func _set_cell(x: int, y: int, type: String) -> void:
	if not type in TILES:
		print_debug("Unknown tile type: ", type)
		return
		
	var variants = TILES[type]
	var variant = variants[_rng.randi() % variants.size()]
	
	# Hex coordinates need offset logic? 
	# Godot TileMapLayer handles odd-r/even-r if configured.
	# Assuming standard grid coordinates for now.
	tile_map.set_cell(Vector2i(x, y), variant.source_id, variant.atlas_coord)

func _create_noise(seed_n: int, period: float) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_n
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / period
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = persistence
	return noise
