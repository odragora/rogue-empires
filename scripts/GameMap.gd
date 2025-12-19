extends Node2D

@export var map_width: int = 100
@export var map_height: int = 100

# TileMap Layer
@onready var tile_map: TileMapLayer = $TileMapLayer

# Atlas Coords for the TileSet
const TILES = {
	"dirt": [
		{ "source_id": 0, "atlas_coord": Vector2i(0, 1) },
		{ "source_id": 0, "atlas_coord": Vector2i(1, 1) },
	],
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
