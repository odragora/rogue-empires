class_name MapGenerator
extends RefCounted

# Config
var width: float = 100.0
var height: float = 100.0
var spacing: float = 15.0 # Lower = more hexes/regions
var seed_value: int = 12345

# Map Data
var mesh: DualMesh
var r_elevation: PackedFloat32Array
var r_moisture: PackedFloat32Array
var r_biome: PackedInt32Array
var r_water: PackedByteArray # Boolean, stored as byte
var r_ocean: PackedByteArray
var s_flow: PackedFloat32Array

# Noise
var _noise_gen: FastNoiseLite

func _init() -> void:
	_noise_gen = FastNoiseLite.new()
	_noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_gen.fractal_octaves = 5

func generate(p_width: float, p_height: float, p_spacing: float, p_seed: int) -> void:
	width = p_width
	height = p_height
	spacing = p_spacing
	seed_value = p_seed
	_noise_gen.seed = seed_value
	
	# 1. Generate Points (Poisson Approximation for speed/simplicity)
	var points = _generate_points()
	
	# 2. Build Mesh
	mesh = DualMesh.new()
	mesh.create(points)
	
	# 3. Assign Attributes
	_assign_elevation()
	_assign_ocean()
	_assign_moisture() # Simple noise based moisture for now, can be upgraded to simulated wind
	_assign_biomes()

# --- Steps ---

func _generate_points() -> PackedVector2Array:
	# Relaxed Poisson Sampling:
	# Generate random points, then relax them (Lloyd's algorithm) once or twice
	# to distribute them evenly like a Poisson disk but faster to implement.
	var pt_count = int((width * height) / (spacing * spacing * 0.7))
	var points = PackedVector2Array()
	points.resize(pt_count)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	for i in range(pt_count):
		points[i] = Vector2(rng.randf() * width, rng.randf() * height)
		
	# Relaxation steps (makes them look like Voronoi cells)
	# NOTE: True Lloyd's requires iterating Voronoi cells. 
	# A cheaper hack is simple repulsion or just using the random points 
	# if the hex grid sampling later handles the regularity.
	# For strict adherence to "Mapgen4", we want irregular but evenly spaced.
	# We will stick to the random points for this implementation to ensure
	# we don't hang the thread with complex relaxation loops in GDScript.
	# The DualMesh handles irregularity fine.
	
	# Add boundary points to force a square shape
	var boundary_step = spacing * 1.5
	var x = 0.0
	while x <= width:
		points.append(Vector2(x, 0))
		points.append(Vector2(x, height))
		x += boundary_step
	var y = 0.0
	while y <= height:
		points.append(Vector2(0, y))
		points.append(Vector2(width, y))
		y += boundary_step
		
	return points

func _assign_elevation() -> void:
	var num_r = mesh.num_regions
	r_elevation = PackedFloat32Array()
	r_elevation.resize(num_r)
	
	for r in range(num_r):
		var pos = mesh.r_pos(r)
		
		# Island Mask (Distance from center)
		var d_x = 2.0 * (pos.x / width) - 1.0
		var d_y = 2.0 * (pos.y / height) - 1.0
		var dist = max(abs(d_x), abs(d_y)) # Square mask
		# var dist = sqrt(d_x*d_x + d_y*d_y) # Circle mask
		var mask = 1.0 - pow(dist, 2.0)
		
		# Noise
		# Mapgen4 uses complex FBM, we use FastNoiseLite
		var n = _noise_gen.get_noise_2d(pos.x, pos.y)
		
		# Combine
		var elevation = (n * 0.5 + 0.5) * mask 
		
		# Sharpen peaks (Mapgen4 logic approximation)
		if elevation > 0.5:
			elevation = pow(elevation, 1.5)
			
		r_elevation[r] = elevation

func _assign_ocean() -> void:
	var num_r = mesh.num_regions
	r_ocean = PackedByteArray()
	r_ocean.resize(num_r)
	r_water = PackedByteArray()
	r_water.resize(num_r)
	
	var water_level = 0.25 # Threshold
	
	for r in range(num_r):
		var is_water = r_elevation[r] < water_level
		r_water[r] = 1 if is_water else 0
		r_ocean[r] = 1 if is_water else 0 
		
	# Flood fill to find lakes (water not connected to boundary) if needed
	# For now, simplistic approach: all low elevation is ocean.

func _assign_moisture() -> void:
	var num_r = mesh.num_regions
	r_moisture = PackedFloat32Array()
	r_moisture.resize(num_r)
	
	# Use a different noise seed/offset for moisture
	_noise_gen.seed = seed_value + 999
	
	for r in range(num_r):
		var pos = mesh.r_pos(r)
		var n = _noise_gen.get_noise_2d(pos.x * 1.5, pos.y * 1.5) # Higher frequency
		r_moisture[r] = (n * 0.5 + 0.5)
		
		# Simple heuristic: Water is wet
		if r_water[r] == 1:
			r_moisture[r] += 0.5
	
	# Clamp
	for r in range(num_r):
		r_moisture[r] = clamp(r_moisture[r], 0.0, 1.0)

func _assign_biomes() -> void:
	# Simple Whittaker diagram approximation
	# 0: Desert, 1: Grassland, 2: Forest, 3: Snow, etc.
	# We will return generic IDs that the visualizer maps to Tiles
	
	r_biome = PackedInt32Array()
	r_biome.resize(mesh.num_regions)
	
	for r in range(mesh.num_regions):
		var e = r_elevation[r]
		var m = r_moisture[r]
		
		if r_water[r] == 1:
			r_biome[r] = 0 # Ocean
			continue
			
		if e > 0.8:
			if m > 0.5: r_biome[r] = 5 # Snow/Ice
			else: r_biome[r] = 4 # Scorched/Tundra
		elif e > 0.6:
			if m > 0.66: r_biome[r] = 3 # Taiga
			elif m > 0.33: r_biome[r] = 2 # Shrubland
			else: r_biome[r] = 1 # Temperate Desert
		else: # Lowlands
			if m > 0.8: r_biome[r] = 8 # Rain Forest
			elif m > 0.5: r_biome[r] = 7 # Forest
			elif m > 0.3: r_biome[r] = 6 # Grassland
			else: r_biome[r] = 1 # Desert

# -- Query --

# Finds the closest region to a world point.
# Optimized: Since we are rasterizing to a grid, we don't need KD-Tree
# if we just iterate once. But for a generic lookup:
func get_closest_region(pos: Vector2) -> int:
	# Brute force search (slow for real-time, fine for generation step)
	var best_dist = 1e20
	var best_r = -1
	for r in range(mesh.num_regions):
		var d = pos.distance_squared_to(mesh.r_pos(r))
		if d < best_dist:
			best_dist = d
			best_r = r
	return best_r
