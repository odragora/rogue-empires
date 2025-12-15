class_name CameraController
extends Camera2D

# Configurable parameters
@export var min_zoom: float = 0.1
@export var max_zoom: float = 2.0
@export var zoom_rate: float = 0.1
@export var zoom_speed: float = 10.0 # How fast the smooth zoom interpolation is

@export var pan_speed: float = 500.0 # Pixel/sec for keyboard panning
@export var drag_sensitivity: float = 1.0

# Internal state
var _target_zoom: Vector2 = Vector2.ONE
var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set this camera as the active one
	make_current()
	_target_zoom = zoom

func _unhandled_input(event: InputEvent) -> void:
	# 1. Handle Zooming (Mouse Wheel)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(1.0 + zoom_rate)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(1.0 - zoom_rate)
			
		# 2. Handle Panning (Mouse Drag)
		# Middle mouse or Right mouse usually used for panning
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_dragging = true
				_last_mouse_pos = event.position
			else:
				_is_dragging = false
	
	elif event is InputEventMouseMotion and _is_dragging:
		var delta_pos = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		
		# Move camera opposite to drag direction, scaled by zoom (so dragging feels 1:1)
		# We divide by zoom.x because when zoomed in (high zoom value), 
		# we need to move FEWER world units for the same screen pixel movement.
		position -= delta_pos * (1.0 / zoom.x) * drag_sensitivity

func _process(delta: float) -> void:
	# 3. Handle Keyboard Panning
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		# Panning speed should also scale with zoom so it's not too fast when zoomed in
		position += input_dir * pan_speed * (1.0 / zoom.x) * delta

	# 4. Smooth Zoom
	# Interpolate current zoom towards target zoom
	if zoom != _target_zoom:
		zoom = zoom.lerp(_target_zoom, zoom_speed * delta)

func zoom_camera(factor: float) -> void:
	# Calculate new zoom target
	# Note: zoom_camera(1.1) means ZOOM IN (multiply zoom). 
	# But users often think scrolling UP zooms IN.
	# Godot zoom < 1 is zoomed out? No, Godot zoom > 1 is zoomed IN (things look bigger).
	# So WHEEL_UP should INCREASE zoom value.
	
	if factor > 1.0: # Zooming In
		_target_zoom *= factor
	else: # Zooming Out
		_target_zoom *= factor
		
	# Clamp zoom
	_target_zoom.x = clamp(_target_zoom.x, min_zoom, max_zoom)
	_target_zoom.y = clamp(_target_zoom.y, min_zoom, max_zoom)
