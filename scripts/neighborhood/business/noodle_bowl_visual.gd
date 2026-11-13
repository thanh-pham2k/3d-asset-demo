extends Node3D

## Procedural visual for a prepared bowl; gameplay and collision remain elsewhere.
var noodles: Node3D
var broth: Node3D
var toppings: Node3D
var last_stage: int = -1
var last_dish: String = ""

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
	set_content(0, "")

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

func set_content(stage: int, dish: String) -> void:
	if not is_instance_valid(noodles): return
	if stage == last_stage and dish == last_dish: return
	last_stage = stage
	last_dish = dish
	visible = stage > 0
	noodles.visible = stage >= 2
	broth.visible = stage >= 3
	toppings.visible = stage >= 4
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
