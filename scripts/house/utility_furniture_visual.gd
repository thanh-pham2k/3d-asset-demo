extends Node3D

## Decorative, base-origin low-poly furniture; placement supplies collision separately.
@export_enum("bath_sink", "bath_mirror", "shower", "toilet", "towel_rack", "washing_machine", "laundry_basket", "clothes_hanger", "broom", "mop") var kind := "bath_sink"

func _ready() -> void:
	var white := Color("f5eddf")
	var wood := Color("ad805f")
	var steel := Color("94a6a4")
	var sage := Color("9ab6a4")
	match kind:
		"bath_sink":
			Art.box(self, Vector3(0, 0.38, 0), Vector3(0.55, 0.76, 0.38), white)
			Art.box(self, Vector3(0, 0.80, 0), Vector3(0.72, 0.12, 0.48), white)
			Art.box(self, Vector3(0, 0.87, 0.02), Vector3(0.43, 0.02, 0.27), Color("b9d5d0"))
			Art.box(self, Vector3(0, 1.00, -0.16), Vector3(0.04, 0.24, 0.04), steel)
			Art.box(self, Vector3(0, 1.10, -0.10), Vector3(0.04, 0.04, 0.16), steel)
		"bath_mirror":
			Art.box(self, Vector3(0, 1.1, 0), Vector3(0.72, 0.9, 0.08), wood)
			Art.box(self, Vector3(0, 1.1, 0.05), Vector3(0.62, 0.8, 0.03), Color("b8d5d4"))
		"shower":
			Art.box(self, Vector3(0, 1.1, 0), Vector3(0.06, 2.0, 0.06), steel)
			Art.box(self, Vector3(0, 2.05, 0.13), Vector3(0.06, 0.06, 0.28), steel)
			_cylinder(Vector3(0, 2.0, 0.24), 0.16, 0.16, 0.05, steel)
			Art.box(self, Vector3(0, 0.03, 0.15), Vector3(0.8, 0.06, 0.8), white)
		"toilet":
			Art.box(self, Vector3(0, 0.55, -0.20), Vector3(0.48, 0.72, 0.22), white)
			_cylinder(Vector3(0, 0.26, 0.08), 0.27, 0.18, 0.48, white)
			_cylinder(Vector3(0, 0.52, 0.08), 0.25, 0.25, 0.04, Color("d5e3de"))
		"towel_rack":
			for x in [-0.3, 0.3]:
				Art.box(self, Vector3(x, 0.7, 0), Vector3(0.04, 1.4, 0.04), steel)
			Art.box(self, Vector3(0, 1.32, 0), Vector3(0.64, 0.04, 0.04), steel)
			Art.box(self, Vector3(0, 1.04, 0), Vector3(0.42, 0.48, 0.07), Color("e6b8a2"))
		"washing_machine":
			Art.box(self, Vector3(0, 0.48, 0), Vector3(0.7, 0.96, 0.66), white)
			var door := Node3D.new()
			add_child(door)
			door.position = Vector3(0, 0.48, 0.34)
			door.rotation.x = PI / 2.0
			_cylinder(Vector3.ZERO, 0.25, 0.25, 0.05, steel, door)
			_cylinder(Vector3(0, 0.035, 0), 0.19, 0.19, 0.015, Color("a9c9c9"), door)
			Art.box(self, Vector3(0.18, 0.83, 0.34), Vector3(0.22, 0.07, 0.03), sage)
		"laundry_basket":
			_cylinder(Vector3(0, 0.25, 0), 0.28, 0.23, 0.5, Color("cba780"))
			Art.ball(self, Vector3(0, 0.49, 0), 0.21, Color("e6c4b5"), Vector3(1, 0.35, 1))
		"clothes_hanger":
			Art.box(self, Vector3(0, 0.85, 0), Vector3(0.05, 1.7, 0.05), wood)
			Art.box(self, Vector3(0, 1.55, 0), Vector3(0.75, 0.05, 0.05), wood)
			for x in [-0.28, 0.28]:
				Art.box(self, Vector3(x, 0.04, 0), Vector3(0.35, 0.08, 0.35), wood)
			Art.box(self, Vector3(-0.16, 1.15, 0), Vector3(0.27, 0.60, 0.05), sage)
		"broom", "mop":
			Art.box(self, Vector3(0, 0.72, 0), Vector3(0.05, 1.44, 0.05), wood, Vector3(0, 0, -0.08))
			Art.box(self, Vector3(0, 0.10, 0), Vector3(0.35, 0.18, 0.15), Color("d5b77f") if kind == "broom" else Color("b6d3cc"))

func _cylinder(pos: Vector3, top: float, bottom: float, height: float, color: Color, parent: Node3D = null) -> void:
	if not is_instance_valid(parent): parent = self
	var geometry := CylinderMesh.new()
	geometry.top_radius = top
	geometry.bottom_radius = bottom
	geometry.height = height
	geometry.radial_segments = 10
	var part := MeshInstance3D.new()
	part.mesh = geometry
	part.material_override = Art.material(color)
	part.position = pos
	parent.add_child(part)
