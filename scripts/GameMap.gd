extends Node2D

@export var map_width: int = 100
@export var map_height: int = 100
@export var hex_size: float = 128.0 # In pixels, radius approx
@export var generation_seed: int = 12345

# TileMap Layer (Ensure you have a TileMapLayer node child or assign it)
@onready var tile_map: TileMapLayer = $TileMapLayer

# Atlas Coords for your TileSet (Source ID 0 assumed)
# Update these to match your specific TileSet assets
const TILES = {
	0: { "source_id": 0, "atlas_coord": Vector2i(0, 8) }, # Ocean
	1: { "source_id": 0, "atlas_coord": Vector2i(0, 1) }, # Desert
	2: { "source_id": 0, "atlas_coord": Vector2i(0, 12) }, # Shrubland
	3: { "source_id": 1, "atlas_coord": Vector2i(0, 2) }, # Taiga
	4: { "source_id": 0, "atlas_coord": Vector2i(2, 3) }, # Tundra
	5: { "source_id": 1, "atlas_coord": Vector2i(0, 0) }, # Snow
	6: { "source_id": 0, "atlas_coord": Vector2i(0, 9) }, # Grassland
	7: { "source_id": 0, "atlas_coord": Vector2i(0, 3) }, # Forest
	8: { "source_id": 1, "atlas_coord": Vector2i(0, 0) }  # Rain Forest
}

func _ready() -> void:
	if tile_map == null:
		push_error("TileMapLayer not found. Please add a TileMapLayer child node.")
		return

	# Setup Camera
	var camera = CameraController.new()
	camera.zoom = Vector2(0.2, 0.2)
	add_child(camera)
	
	# Optional: Center camera roughly on the map
	# Hex width ~ hex_size * sqrt(3) ~= hex_size * 1.732
	# Map pixel width approx: map_width * hex_size * 1.732
	# Center X = (map_width * hex_size * 1.732) / 2
	var center_x = map_width * hex_size * 0.866 
	var center_y = map_height * hex_size * 0.75 # Vert spacing is 1.5 * radius, roughly
	camera.position = Vector2(center_x, center_y)
		
	generate_new_map()

func generate_new_map() -> void:
	tile_map.clear()
	
	# 1. Setup Map Generator
	var generator = MapGenerator.new()
	
	# Determine logical size for the Voronoi generator
	# We want the Voronoi mesh to cover the pixel area of the hex grid
	# Approx pixel width = map_width * hex_size * sqrt(3)
	var pixel_width = map_width * hex_size * 1.8
	var pixel_height = map_height * hex_size * 1.6
	
	# Spacing determines how "chunky" the voronoi cells are relative to hexes.
	# If spacing ~= hex_size, 1 region maps to ~1 hex.
	# If spacing > hex_size, multiple hexes form a region (Civ 6 style "continents" look).
	var spacing = hex_size * 2.0 
	
	print("Generating Dual Mesh...")
	generator.generate(pixel_width, pixel_height, spacing, generation_seed)
	
	print("Rasterizing to Hex Grid...")
	# 2. Rasterize to Hex Grid
	# Loop through every hex coordinate
	for x in range(map_width):
		for y in range(map_height):
			var hex_coords = Vector2i(x, y)
			
			# Convert hex to local pixel position
			var pixel_pos = tile_map.map_to_local(hex_coords)
			
			# Find which Voronoi region covers this pixel center
			var region_idx = generator.get_closest_region(pixel_pos)
			
			# Get biome data
			var biome_id = generator.r_biome[region_idx]
			
			# Set Tile
			var tile_data = TILES.get(biome_id)
			if tile_data:
				tile_map.set_cell(hex_coords, tile_data.source_id, tile_data.atlas_coord)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		generation_seed = randi()
		generate_new_map()
