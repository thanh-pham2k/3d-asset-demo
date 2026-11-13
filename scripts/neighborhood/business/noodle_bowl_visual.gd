extends Node3D

## Procedural visual for a prepared bowl; gameplay and collision remain elsewhere.
var noodles: Node3D
var broth: Node3D
var toppings: Node3D
var last_stage: int = -1
var last_dish: String = ""
var last_special: bool = false
var last_veggie: String = ""
var special_ring: MeshInstance3D

func _ready() -> void:
	_cylinder(self, Vector3(0, 0.10, 0), 0.19, 0.13, 0.18, Color("f7f1e5"))
	noodles = Node3D.new()
	add_child(noodles)
	_cylinder(noodles, Vector3(0, 0.19, 0), 0.16, 0.16, 0.025, Color("f7e4ab"))
	broth = Node3D.new()
	add_child(broth)
	_cylinder(broth, Vector3(0, 0.205, 0), 0.165, 0.165, 0.012, Color("d6ae72"))
	toppings = Node3D.new()
	add_child(toppings)
	special_ring = _create_special_ring()
	add_child(special_ring)
	set_content(0, "")

func _create_special_ring() -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.20
	torus.outer_radius = 0.23
	torus.rings = 16
	torus.ring_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd54f")
	mat.emission_enabled = true
	mat.emission = Color("ffca28")
	mat.emission_energy_multiplier = 1.6
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = torus
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0, 0.17, 0)
	mesh_inst.visible = false
	return mesh_inst

func _cylinder(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, color: Color) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 12
	var part := MeshInstance3D.new()
	part.mesh = shape
	part.material_override = Art.material(color)
	part.position = pos
	parent.add_child(part)

func set_content(stage: int, dish: String, is_special: bool = false, veggie_id: String = "") -> void:
	if not is_instance_valid(noodles): return
	if stage == last_stage and dish == last_dish and is_special == last_special and veggie_id == last_veggie: return
	last_stage = stage
	last_dish = dish
	last_special = is_special
	last_veggie = veggie_id
	visible = stage > 0
	noodles.visible = stage >= 2
	broth.visible = stage >= 3
	toppings.visible = stage >= 4
	if is_instance_valid(special_ring):
		special_ring.visible = stage >= 4 and is_special
	for child in toppings.get_children():
		child.queue_free()
	if stage < 4: return
	var topping_color := Color("ee9c79")
	if "sườn" in dish.to_lower(): topping_color = Color("b47758")
	elif "rau cải" in dish.to_lower(): topping_color = Color("74a35f")
	elif "Nam Vang" in dish: topping_color = Color("ead6ae")
	for i in range(4):
		var angle := float(i) * TAU / 4.0
		Art.ball(toppings, Vector3(cos(angle) * 0.09, 0.23, sin(angle) * 0.09), 0.045, topping_color, Vector3(1.0, 0.5, 0.8))
	for i in range(3):
		var angle := float(i) * TAU / 3.0 + 0.5
		Art.box(toppings, Vector3(cos(angle) * 0.11, 0.235, sin(angle) * 0.11), Vector3(0.055, 0.015, 0.025), Color("5f9a5a"))
	if is_special:
		var garnish_color := Color("69f0ae")
		if veggie_id == "produce_carrot":
			garnish_color = Color("ff8a24")
		elif veggie_id == "produce_tomato":
			garnish_color = Color("ef5350")
		elif veggie_id == "produce_lettuce":
			garnish_color = Color("66bb6a")
		for i in range(5):
			var angle := float(i) * TAU / 5.0 + 0.25
			Art.ball(toppings, Vector3(cos(angle) * 0.06, 0.255, sin(angle) * 0.06), 0.032, garnish_color, Vector3(1.1, 0.85, 1.1))
		Art.ball(toppings, Vector3(0, 0.27, 0), 0.028, Color("ffd54f"), Vector3(1.0, 0.7, 1.0))
