extends SceneTree
# Produce editable, script-free Godot scenes from procedural module sources.
# Source files and GLBs remain untouched; generated nodes retain local pivots.
const OUTPUT := "res://assets/neighborhood/editable"

func _initialize() -> void:
 call_deferred("run")

func copy_nodes(source: Node, parent: Node, owner_root: Node) -> void:
 for child in source.get_children():
  if child is MeshInstance3D:
   var visual := MeshInstance3D.new()
   visual.name = child.name
   visual.transform = child.transform
   visual.mesh = child.mesh
   visual.material_override = child.material_override
   parent.add_child(visual)
   visual.owner = owner_root
   copy_nodes(child,visual,owner_root)
  elif child is StaticBody3D:
   var body := StaticBody3D.new()
   body.name = child.name
   body.transform = child.transform
   body.collision_layer = child.collision_layer
   body.collision_mask = child.collision_mask
   parent.add_child(body)
   body.owner = owner_root
   copy_nodes(child,body,owner_root)
  elif child is CollisionShape3D:
   var collider := CollisionShape3D.new()
   collider.name = child.name
   collider.transform = child.transform
   collider.shape = child.shape
   collider.disabled = child.disabled
   parent.add_child(collider)
   collider.owner = owner_root
  elif child is Node3D:
   var container := Node3D.new()
   container.name = child.name
   container.transform = child.transform
   parent.add_child(container)
   container.owner = owner_root
   copy_nodes(child,container,owner_root)

func run() -> void:
 var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 if result != OK:
  printerr("Failed to create editable library: ",result)
  quit(1)
  return
 var files := DirAccess.open("res://scenes/neighborhood").get_files()
 files.sort()
 var failures := 0
 var overwrite := "--overwrite" in OS.get_cmdline_user_args()
 for file in files:
  if not file.ends_with(".tscn"): continue
  var destination := OUTPUT.path_join(file)
  if FileAccess.file_exists(destination) and not overwrite:
   print("Skipped existing ",file)
   continue
  var original: Node3D = load("res://scenes/neighborhood/"+file).instantiate()
  root.add_child(original)
  var baked := Node3D.new()
  baked.name = original.name
  copy_nodes(original,baked,baked)
  var packed := PackedScene.new()
  var err := packed.pack(baked)
  if err == OK: err = ResourceSaver.save(packed,destination)
  if err != OK:
   failures += 1
   printerr("FAIL baking ",file," error=",err)
  else: print("Baked ",file)
  original.free()
  baked.free()
 print("BAKE_RESULT failures=",failures)
 quit(1 if failures else 0)
