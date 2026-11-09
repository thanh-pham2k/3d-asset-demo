extends SceneTree
var failures := 0
const MODULE := preload("res://scripts/neighborhood/module.gd")
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 if ok: print("PASS: ",label)
 else:
  failures += 1
  printerr("FAIL: ",label)
func count(node: Node, type_name: String) -> int:
 var amount := 1 if node.is_class(type_name) else 0
 for child in node.get_children(): amount += count(child,type_name)
 return amount
func modules(node: Node, baked: bool) -> int:
 var amount := 1 if (node.has_meta("module_kind") if baked else node.get_script() == MODULE) else 0
 for child in node.get_children(): amount += modules(child,baked)
 return amount
func gather(node: Node, parent := Transform3D.IDENTITY) -> Array:
 var transform := parent
 if node is Node3D: transform = parent * node.transform
 var result := []
 if node is MeshInstance3D:
  var material: StandardMaterial3D = node.material_override as StandardMaterial3D
  result.append({"type":"mesh","transform":transform,"bounds":node.mesh.get_aabb(),"color":material.albedo_color if material else Color.TRANSPARENT})
 elif node is CollisionShape3D:
  result.append({"type":node.shape.get_class(),"transform":transform})
 elif node is Marker3D:
  result.append({"type":"marker","transform":transform})
 elif node is Path3D:
  result.append({"type":"path","transform":transform,"points":node.curve.get_point_count()})
 for child in node.get_children(): result.append_array(gather(child,transform))
 return result

func equivalent(a: Array, b: Array) -> bool:
 if a.size() != b.size(): return false
 for i in range(a.size()):
  if a[i].type != b[i].type or not a[i].transform.is_equal_approx(b[i].transform): return false
  if a[i].type == "mesh":
   if not a[i].bounds.is_equal_approx(b[i].bounds) or not a[i].color.is_equal_approx(b[i].color): return false
  elif a[i].type == "path" and a[i].points != b[i].points: return false
 return true

func run() -> void:
 var world: Node3D = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 var packed: PackedScene = load("res://assets/neighborhood/editable_layout.tscn")
 var layout: Node3D = packed.instantiate()
 check(layout.get_script() == null,"snapshot root is script-free")
 check(layout.get_child_count() == 16,"snapshot has 16 district and infrastructure groups")
 for group in layout.get_children():
  var original := world.get_node_or_null(str(group.name))
  if original == null:
   check(false,"source group exists: "+str(group.name))
   continue
  for type_name in ["MeshInstance3D","CollisionShape3D","Path3D","Marker3D"]:
   check(count(group,type_name) == count(original,type_name),str(group.name)+" preserves "+type_name+" count")
  check(modules(group,true) == modules(original,false),str(group.name)+" preserves separate module nodes")
  check(equivalent(gather(original),gather(group)),str(group.name)+" preserves transforms, bounds and colors")
 check(count(layout,"CharacterBody3D") == 0 and count(layout,"Camera3D") == 0,"snapshot excludes gameplay entities and camera")
 print("LAYOUT_RESULT failures=",failures)
 layout.free()
 world.free()
 quit(1 if failures else 0)
