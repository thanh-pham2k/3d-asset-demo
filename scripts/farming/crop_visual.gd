class_name CropVisual
extends Node3D

## Visual Adapter & Stage Swapper for Low-Poly Crops in Couple Chaos 3D.
## Manages 4 distinct visual stages:
## Stage 0: SEEDED (mounded soil with seed furrow)
## Stage 1: SPROUT (baby cotyledon shoot)
## Stage 2: GROWING (developing foliage and unripe blooms)
## Stage 3: MATURE (harvest-ready ripe vegetables/leafy heads)
## Also supports dynamic soil moisture states: "dry", "watered", "empty".

signal stage_changed(stage_index: int, stage_name: String)

enum Stage {
	SEEDED = 0,
	SPROUT = 1,
	GROWING = 2,
	MATURE = 3
}

@export_enum("lettuce", "tomato", "carrot") var crop_type: String = "lettuce"
@export var current_stage: Stage = Stage.SEEDED:
	set(v):
		current_stage = v
		if is_node_ready():
			_update_stage_visibility()

@export_enum("dry", "watered", "empty") var soil_moisture: String = "dry":
	set(v):
		soil_moisture = v
		if is_node_ready():
			_update_soil_visual()

# Stage node references
var stage_seeded: Node3D
var stage_sprout: Node3D
var stage_growing: Node3D
var stage_mature: Node3D

# Soil mesh reference
var soil_node: Node3D

func _ready() -> void:
	add_to_group("crop_visuals")
	
	stage_seeded = get_node_or_null("StageSeeded") as Node3D
	stage_sprout = get_node_or_null("StageSprout") as Node3D
	stage_growing = get_node_or_null("StageGrowing") as Node3D
	stage_mature = get_node_or_null("StageMature") as Node3D
	soil_node = get_node_or_null("Soil") as Node3D
	
	_update_stage_visibility(false)
	_update_soil_visual()

func set_stage(new_stage: int, animate_pop: bool = true) -> void:
	var clamped_stage: Stage = clampi(new_stage, Stage.SEEDED, Stage.MATURE)
	if current_stage == clamped_stage:
		return
	current_stage = clamped_stage
	_update_stage_visibility(animate_pop)
	stage_changed.emit(int(current_stage), get_stage_name())

func next_stage() -> bool:
	if current_stage < Stage.MATURE:
		set_stage(int(current_stage) + 1, true)
		return true
	return false

func get_stage_name() -> String:
	match current_stage:
		Stage.SEEDED: return "SEEDED"
		Stage.SPROUT: return "SPROUT"
		Stage.GROWING: return "GROWING"
		Stage.MATURE: return "MATURE"
		_: return "SEEDED"

func is_harvest_ready() -> bool:
	return current_stage == Stage.MATURE

func _update_stage_visibility(animate_pop: bool = false) -> void:
	if is_instance_valid(stage_seeded): stage_seeded.visible = (current_stage == Stage.SEEDED)
	if is_instance_valid(stage_sprout): stage_sprout.visible = (current_stage == Stage.SPROUT)
	if is_instance_valid(stage_growing): stage_growing.visible = (current_stage == Stage.GROWING)
	if is_instance_valid(stage_mature): stage_mature.visible = (current_stage == Stage.MATURE)
	
	if animate_pop:
		var active_node: Node3D = _get_active_stage_node()
		if is_instance_valid(active_node):
			# Cute low-poly pop bounce scale effect
			active_node.scale = Vector3(0.5, 0.5, 0.5)
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_BACK)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(active_node, "scale", Vector3.ONE, 0.35)

func _get_active_stage_node() -> Node3D:
	match current_stage:
		Stage.SEEDED: return stage_seeded
		Stage.SPROUT: return stage_sprout
		Stage.GROWING: return stage_growing
		Stage.MATURE: return stage_mature
		_: return null

func _update_soil_visual() -> void:
	if not is_instance_valid(soil_node):
		return
	# Darken or lighten soil mesh if present
	var mesh_inst: MeshInstance3D = soil_node.find_child("*Mesh*", true, false) as MeshInstance3D
	if not mesh_inst and soil_node is MeshInstance3D:
		mesh_inst = soil_node
	if is_instance_valid(mesh_inst):
		var mat: StandardMaterial3D = mesh_inst.get_active_material(0) as StandardMaterial3D
		if mat:
			var new_mat := mat.duplicate() as StandardMaterial3D
			match soil_moisture:
				"watered":
					new_mat.albedo_color = Color("382418") # Deep rich moist loam
					new_mat.roughness = 0.45 # Slight wet sheen
				"dry":
					new_mat.albedo_color = Color("a68360") # Dusty pale dry soil
					new_mat.roughness = 0.95
				_: # "empty"
					new_mat.albedo_color = Color("704d33") # Standard brown
					new_mat.roughness = 0.90
			mesh_inst.material_override = new_mat
