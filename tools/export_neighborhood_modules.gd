extends SceneTree
# Export visual-only GLBs from the reusable scene modules. Godot collision
# remains in the original scenes, not embedded as render geometry in glTF.
const OUTPUT := "res://assets/neighborhood/glb"

func _initialize() -> void:
 call_deferred("run")

func copy_visuals(source: Node, destination: Node3D, parent_transform := Transform3D.IDENTITY) -> void:
 for child in source.get_children():
  if child is not Node3D: continue
  var child_transform: Transform3D = parent_transform * child.transform
  if child is MeshInstance3D:
   var visual := MeshInstance3D.new()
   visual.name = child.name
   visual.mesh = child.mesh
   visual.material_override = child.material_override
   visual.transform = child_transform
   destination.add_child(visual)
   visual.owner = destination
  copy_visuals(child, destination, child_transform)

func run() -> void:
 var absolute_dir := ProjectSettings.globalize_path(OUTPUT)
 var result := DirAccess.make_dir_recursive_absolute(absolute_dir)
 if result != OK:
  printerr("Could not create export directory: ", result)
  quit(1)
  return
 var directory := DirAccess.open("res://scenes/neighborhood")
 var files := directory.get_files()
 files.sort()
 var failures := 0
 for file in files:
  if not file.ends_with(".tscn"): continue
  var module: Node3D = load("res://scenes/neighborhood/" + file).instantiate()
  root.add_child(module)
  var visual_root := Node3D.new()
  visual_root.name = file.get_basename()
  copy_visuals(module, visual_root)
  var document := GLTFDocument.new()
  var state := GLTFState.new()
  var err := document.append_from_scene(visual_root, state)
  if err == OK:
   err = document.write_to_filesystem(state, OUTPUT.path_join(file.get_basename() + ".glb"))
  if err != OK or visual_root.get_child_count() == 0:
   printerr("Export failed: ", file, " error=", err)
   failures += 1
  else: print("Exported ", file.get_basename(), " (", visual_root.get_child_count(), " meshes)")
  visual_root.free()
  module.free()
 print("EXPORT_RESULT failures=", failures)
 quit(1 if failures else 0)
