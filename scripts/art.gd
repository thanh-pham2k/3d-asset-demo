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
