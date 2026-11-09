extends SceneTree
# Runtime batching must preserve module bounds, collisions, and cutaway groups.
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func visuals(node: Node, parent := Transform3D.IDENTITY) -> Array:
 var transform := parent
 if node is Node3D: transform = parent * node.transform
 var result := []
 if node is MeshInstance3D and node.mesh != null: result.append(transform * node.mesh.get_aabb())
 for child in node.get_children(): result.append_array(visuals(child, transform))
 return result

func total_bounds(boxes: Array) -> AABB:
 var bounds: AABB = boxes[0]
 for box in boxes.slice(1): bounds = bounds.merge(box)
 return bounds

func run() -> void:
 var files := DirAccess.open("res://scenes/neighborhood").get_files()
 files.sort()
 for file in files:
  if not file.ends_with(".tscn"): continue
  var module = load("res://scenes/neighborhood/" + file).instantiate()
  root.add_child(module)
  var before := visuals(module)
  var colliders: int = module.find_children("*", "CollisionShape3D", true, false).size()
  var had_cutaway: bool = not module.cutaway_meshes.is_empty()
  var had_sides: bool = not module.side_cutaway_meshes.is_empty()
  module.batch_visuals()
  var after := visuals(module)
  var old_bounds := total_bounds(before)
  var new_bounds := total_bounds(after)
  var ok := old_bounds.position.distance_to(new_bounds.position) < 0.08 and old_bounds.size.distance_to(new_bounds.size) < 0.08
  ok = ok and colliders == module.find_children("*", "CollisionShape3D", true, false).size()
  ok = ok and had_cutaway == (not module.cutaway_meshes.is_empty())
  ok = ok and had_sides == (not module.side_cutaway_meshes.is_empty())
  if not ok:
   failures += 1
   printerr("FAIL: batch ",file," bounds/collision/cutaway")
  else: print("PASS: batch ",file," visuals ",before.size()," -> ",after.size())
  module.free()
 print("BATCH_RESULT failures=",failures)
 quit(1 if failures else 0)
