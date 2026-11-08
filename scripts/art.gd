class_name Art
extends RefCounted

static func material(c: Color) -> StandardMaterial3D:
 var m = StandardMaterial3D.new()
 m.albedo_color = c
 m.roughness = 0.88
 return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
 var mesh = MeshInstance3D.new()
 var shape = BoxMesh.new()
 shape.size = size
 mesh.mesh = shape
 mesh.material_override = material(color)
 mesh.position = pos
 mesh.rotation = rot
 parent.add_child(mesh)
 return mesh

static func ball(parent: Node3D, pos: Vector3, radius: float, color: Color, scale_value := Vector3.ONE) -> MeshInstance3D:
 var mesh = MeshInstance3D.new()
 var shape = SphereMesh.new()
 shape.radius = radius
 shape.height = radius * 2.0
 shape.radial_segments = 12
 shape.rings = 6
 mesh.mesh = shape
 mesh.material_override = material(color)
 mesh.position = pos
 mesh.scale = scale_value
 parent.add_child(mesh)
 return mesh

static func solid(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
 var body = StaticBody3D.new()
 body.position = pos
 var collision = CollisionShape3D.new()
 var shape = BoxShape3D.new()
 shape.size = size
 collision.shape = shape
 body.add_child(collision)
 parent.add_child(body)
 return body

# Kenney OBJ files have an off-center origin; normalize the pivot at the base.
static func kenney(parent: Node3D, asset_name: String, pos: Vector3, target_height: float) -> MeshInstance3D:
 var instance := MeshInstance3D.new()
 instance.mesh = load("res://assets/furniture/%s.obj" % asset_name)
 var bounds := instance.mesh.get_aabb()
 var factor := target_height / bounds.size.y
 instance.scale = Vector3.ONE * factor
 instance.position = pos - Vector3(bounds.position.x + bounds.size.x * 0.5, bounds.position.y, bounds.position.z + bounds.size.z * 0.5) * factor
 parent.add_child(instance)
 return instance
