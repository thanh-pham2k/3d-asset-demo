extends Node3D

## Decorative low-poly detail; collision and interaction are owned by the room.
@export_enum("rice_cooker", "wall_clock", "bedside_lamp", "kitchen_shelf") var detail := "rice_cooker"

func _ready() -> void:
	match detail:
		"rice_cooker":
			_cylinder(Vector3(0, 0.13, 0), 0.18, 0.15, 0.24, Color("f3eee0"))
			_cylinder(Vector3(0, 0.27, 0), 0.19, 0.18, 0.05, Color("d7d9c6"))
			Art.ball(self, Vector3(0, 0.31, 0), 0.035, Color("778e79"))
			Art.box(self, Vector3(0, 0.14, 0.166), Vector3(0.13, 0.07, 0.02), Color("aec5af"))
		"wall_clock":
			var face := Node3D.new()
			add_child(face)
			face.rotation.x = PI / 2.0
			_cylinder(Vector3.ZERO, 0.23, 0.23, 0.055, Color("8c634e"), face)
			_cylinder(Vector3(0, 0.031, 0), 0.19, 0.19, 0.012, Color("f8ecd7"), face)
			Art.box(face, Vector3(0, 0.04, -0.04), Vector3(0.018, 0.012, 0.11), Color("51463f"))
			Art.box(face, Vector3(0.045, 0.04, 0), Vector3(0.10, 0.012, 0.018), Color("51463f"))
		"bedside_lamp":
			_cylinder(Vector3(0, 0.02, 0), 0.14, 0.14, 0.04, Color("957558"))
			_cylinder(Vector3(0, 0.17, 0), 0.025, 0.025, 0.28, Color("957558"))
			_cylinder(Vector3(0, 0.36, 0), 0.11, 0.18, 0.22, Color("f1cfad"))
		"kitchen_shelf":
			Art.box(self, Vector3.ZERO, Vector3(1.25, 0.07, 0.30), Color("b47c55"))
			for x in [-0.45, -0.20, 0.05, 0.30]:
				_cylinder(Vector3(x, 0.14, 0), 0.08, 0.075, 0.22, Color("eee1cf") if x < 0.0 else Color("abc4aa"))

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
