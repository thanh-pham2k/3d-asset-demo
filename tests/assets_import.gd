extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var holder := Node3D.new()
 root.add_child(holder)
 for kind in ["cup", "bottle"]:
  var prop = load("res://scripts/physics_prop.gd").new()
  prop.prop_kind = kind
  holder.add_child(prop)
  var meshes = prop.find_children("*", "MeshInstance3D", true, false)
  var material = meshes[0].get_active_material(0) if not meshes.is_empty() else null
  check(material is StandardMaterial3D and material.albedo_texture != null, kind + " imported model and texture bound")
 holder.queue_free()
 await process_frame
 print("ASSET_IMPORT_RESULT failures=",failures)
 quit(0 if failures == 0 else 1)
