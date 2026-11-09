extends SceneTree
# Round-trip exported modules through Godot's glTF importer.
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func count_visuals(node: Node) -> int:
 var count := 1 if node is MeshInstance3D and node.mesh != null else 0
 for child in node.get_children(): count += count_visuals(child)
 return count

func visual_bounds(node: Node, parent_transform := Transform3D.IDENTITY) -> Array:
 var transform := parent_transform
 if node is Node3D: transform = parent_transform * node.transform
 var bounds := []
 if node is MeshInstance3D and node.mesh != null:
  bounds.append(transform * node.mesh.get_aabb())
 for child in node.get_children(): bounds.append_array(visual_bounds(child, transform))
 return bounds

func combined_bounds(bounds: Array) -> AABB:
 var result: AABB = bounds[0]
 for box in bounds.slice(1): result = result.merge(box)
 return result

func run() -> void:
 var files := DirAccess.open("res://scenes/neighborhood").get_files()
 files.sort()
 for file in files:
  if not file.ends_with(".tscn"): continue
  var name := file.get_basename()
  var module: Node3D = load("res://scenes/neighborhood/" + file).instantiate()
  root.add_child(module)
  var expected := count_visuals(module)
  var doc := GLTFDocument.new()
  var state := GLTFState.new()
  var path := "res://assets/neighborhood/glb/" + name + ".glb"
  var error := doc.append_from_file(path, state)
  var imported: Node = doc.generate_scene(state) if error == OK else null
  var actual := count_visuals(imported) if imported else 0
  if error != OK or expected == 0 or expected != actual:
   failures += 1
   printerr("FAIL: ", name, " GLB: expected ", expected, " meshes, got ", actual, " error=", error)
  else:
   var source_bounds := combined_bounds(visual_bounds(module))
   var imported_bounds := combined_bounds(visual_bounds(imported))
   if source_bounds.position.distance_to(imported_bounds.position) > 0.08 or source_bounds.size.distance_to(imported_bounds.size) > 0.08:
    failures += 1
    printerr("FAIL: ", name, " GLB bounds differ: ", source_bounds, " vs ", imported_bounds)
   else: print("PASS: ", name, " GLB round trip (", actual, " meshes; bounds match)")
  if imported: imported.free()
  module.free()
 print("GLB_RESULT failures=", failures)
 quit(1 if failures else 0)
