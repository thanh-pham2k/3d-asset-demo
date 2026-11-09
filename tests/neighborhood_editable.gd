extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func describe(node: Node, parent := Transform3D.IDENTITY) -> Dictionary:
 var transform := parent
 if node is Node3D: transform = parent * node.transform
 var visuals := []
 var colliders := []
 var materials := []
 if node is MeshInstance3D and node.mesh:
  visuals.append(transform * node.mesh.get_aabb())
  var material: StandardMaterial3D = node.material_override as StandardMaterial3D
  materials.append(material.albedo_color if material else Color.TRANSPARENT)
 if node is CollisionShape3D and node.shape:
  colliders.append({"transform":transform,"shape":node.shape})
 for child in node.get_children():
  var data := describe(child, transform)
  visuals.append_array(data.visuals)
  colliders.append_array(data.colliders)
  materials.append_array(data.materials)
 return {"visuals":visuals,"colliders":colliders,"materials":materials}

func run() -> void:
 var files := DirAccess.open("res://scenes/neighborhood").get_files()
 files.sort()
 for file in files:
  if not file.ends_with(".tscn"): continue
  var source: Node3D = load("res://scenes/neighborhood/"+file).instantiate()
  root.add_child(source)
  var baked_scene: PackedScene = load("res://assets/neighborhood/editable/"+file)
  var baked: Node3D = baked_scene.instantiate() if baked_scene else null
  if not baked:
   failures += 1
   printerr("FAIL: missing editable module ",file)
   source.free()
   continue
  var a := describe(source)
  var b := describe(baked)
  var ok: bool = baked.get_script() == null and a.visuals.size() > 0 and a.visuals.size() == b.visuals.size() and a.colliders.size() == b.colliders.size()
  if ok:
   for i in range(a.visuals.size()):
    if a.visuals[i].position.distance_to(b.visuals[i].position) > 0.001 or a.visuals[i].size.distance_to(b.visuals[i].size) > 0.001: ok = false
    if not a.materials[i].is_equal_approx(b.materials[i]): ok = false
   for i in range(a.colliders.size()):
    if not a.colliders[i].transform.is_equal_approx(b.colliders[i].transform): ok = false
    var source_shape: Shape3D = a.colliders[i].shape
    var saved_shape: Shape3D = b.colliders[i].shape
    if source_shape.get_class() != saved_shape.get_class(): ok = false
    elif source_shape is BoxShape3D and not source_shape.size.is_equal_approx(saved_shape.size): ok = false
    elif source_shape is CylinderShape3D and (not is_equal_approx(source_shape.radius,saved_shape.radius) or not is_equal_approx(source_shape.height,saved_shape.height)): ok = false
  if not ok:
   failures += 1
   printerr("FAIL: editable module ",file," visuals ",a.visuals.size(),"/",b.visuals.size()," collisions ",a.colliders.size(),"/",b.colliders.size())
  else: print("PASS: editable ",file," visuals=",b.visuals.size()," collisions=",b.colliders.size())
  baked.free()
  source.free()
 print("EDITABLE_RESULT failures=",failures)
 quit(1 if failures else 0)
