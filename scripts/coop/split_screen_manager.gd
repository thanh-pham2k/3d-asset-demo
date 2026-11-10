class_name SplitScreenManager
extends Control

## Manages split-screen viewports and cameras for local 2-player cooperative mode.
## Creates two SubViewports sharing the authoritative 3D World.
## Left viewport tracks Player 1, Right viewport tracks Player 2.

enum LayoutMode { SINGLE_PLAYER, SPLIT_HORIZONTAL }
var current_mode: LayoutMode = LayoutMode.SINGLE_PLAYER

var container_left: SubViewportContainer
var container_right: SubViewportContainer
var viewport_left: SubViewport
var viewport_right: SubViewport

var camera_p1: Camera3D
var camera_p2: Camera3D

var target_p1: Node3D
var target_p2: Node3D

var divider: ColorRect

var camera_offset := Vector3(0, 25, 22)
var camera_ortho_size := 20.0
var camera_projection := Camera3D.PROJECTION_ORTHOGONAL

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_IGNORE

func setup_coop(p1: Node3D, p2: Node3D, parent_world_3d: World3D, is_room: bool = false) -> void:
	target_p1 = p1
	target_p2 = p2
	
	if is_room:
		camera_offset = Vector3(0, 12.5, 13.5)
		camera_ortho_size = 9.0
	else:
		camera_offset = Vector3(0, 25, 22)
		camera_ortho_size = 20.0

	_build_split_screen(parent_world_3d)

func _build_split_screen(shared_world: World3D) -> void:
	current_mode = LayoutMode.SPLIT_HORIZONTAL
	
	# Clear previous
	for child in get_children():
		child.queue_free()
	
	# 1. Left Viewport Container (Player 1: 0% to 50% width)
	container_left = SubViewportContainer.new()
	container_left.name = "ViewportP1"
	container_left.stretch = true
	container_left.anchor_top = 0.0
	container_left.anchor_bottom = 1.0
	container_left.anchor_left = 0.0
	container_left.anchor_right = 0.5
	add_child(container_left)
	
	viewport_left = SubViewport.new()
	viewport_left.name = "SubViewportP1"
	viewport_left.world_3d = shared_world
	viewport_left.own_world_3d = false
	viewport_left.handle_input_locally = true
	container_left.add_child(viewport_left)
	
	camera_p1 = Camera3D.new()
	camera_p1.name = "CameraP1"
	camera_p1.projection = camera_projection
	camera_p1.size = camera_ortho_size
	camera_p1.current = true
	viewport_left.add_child(camera_p1)
	if is_instance_valid(target_p1):
		camera_p1.position = target_p1.position + camera_offset
		if camera_p1.is_inside_tree():
			camera_p1.look_at(target_p1.global_position)
	
	# 2. Right Viewport Container (Player 2: 50% to 100% width)
	container_right = SubViewportContainer.new()
	container_right.name = "ViewportP2"
	container_right.stretch = true
	container_right.anchor_top = 0.0
	container_right.anchor_bottom = 1.0
	container_right.anchor_left = 0.5
	container_right.anchor_right = 1.0
	add_child(container_right)
	
	viewport_right = SubViewport.new()
	viewport_right.name = "SubViewportP2"
	viewport_right.world_3d = shared_world # Share exact same 3D world!
	viewport_right.own_world_3d = false
	viewport_right.handle_input_locally = true
	container_right.add_child(viewport_right)
	
	camera_p2 = Camera3D.new()
	camera_p2.name = "CameraP2"
	camera_p2.projection = camera_projection
	camera_p2.size = camera_ortho_size
	camera_p2.current = true
	viewport_right.add_child(camera_p2)
	if is_instance_valid(target_p2):
		camera_p2.position = target_p2.position + camera_offset
		if camera_p2.is_inside_tree():
			camera_p2.look_at(target_p2.global_position)
	
	# 3. Vertical Divider Line
	divider = ColorRect.new()
	divider.name = "Divider"
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.anchor_top = 0.0
	divider.anchor_bottom = 1.0
	divider.offset_left = -2.0
	divider.offset_right = 2.0
	divider.color = Color("263238") # Dark slate dividing border
	add_child(divider)
	
	# Player Labels in Viewport corners
	_add_viewport_overlay(container_left, "P1 — Boy (Bàn phím)", Color("80d8ff"))
	_add_viewport_overlay(container_right, "P2 — Girl (Tay cầm)", Color("ff80ab"))

func _add_viewport_overlay(parent: Control, label_text: String, tag_color: Color) -> void:
	var badge := PanelContainer.new()
	badge.offset_left = 16
	badge.offset_top = 16
	parent.add_child(badge)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", tag_color)
	badge.add_child(lbl)

func _process(delta: float) -> void:
	if current_mode != LayoutMode.SPLIT_HORIZONTAL: return
	
	# Smooth independent camera tracking
	if is_instance_valid(camera_p1) and is_instance_valid(target_p1):
		var target_pos := target_p1.global_position + camera_offset
		camera_p1.global_position = camera_p1.global_position.lerp(target_pos, 1.0 - exp(-8.0 * delta))
		camera_p1.look_at(target_p1.global_position)
		
	if is_instance_valid(camera_p2) and is_instance_valid(target_p2):
		var target_pos := target_p2.global_position + camera_offset
		camera_p2.global_position = camera_p2.global_position.lerp(target_pos, 1.0 - exp(-8.0 * delta))
		camera_p2.look_at(target_p2.global_position)
