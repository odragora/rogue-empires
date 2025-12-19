extends Node2D

@export var map_width: int = 100
@export var map_height: int = 100
@export var hex_size: float = 128.0 # In pixels, radius

# TileMap Layer
@onready var tile_map: TileMapLayer = $TileMapLayer

# Atlas Coords for the TileSet
const TILES = {
	"ocean": { "source_id": 0, "atlas_coord": Vector2i(0, 8) },
	"desert": { "source_id": 0, "atlas_coord": Vector2i(0, 1) },
	"steppe": { "source_id": 0, "atlas_coord": Vector2i(0, 10) },
	"dirt": { "source_id": 0, "atlas_coord": Vector2i(0, 2) },
	"mountain": { "source_id": 0, "atlas_coord": Vector2i(0, 7) },
	"hills": { "source_id": 0, "atlas_coord": Vector2i(0, 5) },
	"snow": { "source_id": 1, "atlas_coord": Vector2i(0, 3) },
	"grassland": { "source_id": 0, "atlas_coord": Vector2i(0, 9) },
	"forest": { "source_id": 0, "atlas_coord": Vector2i(0, 3) },
}

func _ready() -> void:
	# Setup Camera
	var camera = CameraController.new()
	camera.zoom = Vector2(0.2, 0.2)
	add_child(camera)
		
	generate_new_map()

func generate_new_map() -> void:
	tile_map.clear()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		# TODO: Generate new map
		pass
