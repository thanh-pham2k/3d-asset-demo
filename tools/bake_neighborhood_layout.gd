extends SceneTree
# Snapshot the procedural layout as editable district/module nodes. It is an
# authoring reference, not the playable scene or a merged world mesh.
const OUTPUT := "res://assets/neighborhood/editable_layout.tscn"
const MODULE := preload("res://scripts/neighborhood/module.gd")

func _initialize() -> void:
 call_deferred("run")

func clone_node(source: Node) -> Node:
 if source is MeshInstance3D:
  var mesh := MeshInstance3D.new()
  mesh.mesh = source.mesh
  mesh.material_override = source.material_override
  mesh.transform = source.transform
  mesh.visible = true # Never freeze a runtime camera cutaway into the snapshot.
  return mesh
 if source is StaticBody3D:
  var body := StaticBody3D.new()
  body.transform = source.transform
  body.collision_layer = source.collision_layer
  body.collision_mask = source.collision_mask
  return body
 if source is CollisionShape3D:
  var shape := CollisionShape3D.new()
  shape.transform = source.transform
  shape.shape = source.shape
  shape.disabled = source.disabled
  return shape
 if source is Path3D:
  var path := Path3D.new()
  path.transform = source.transform
  path.curve = source.curve.duplicate()
  return path
 if source is Marker3D:
  var marker := Marker3D.new()
  marker.transform = source.transform
  return marker
 if source is Node3D:
  var group := Node3D.new()
  group.transform = source.transform
  if source.get_script() == MODULE:
   group.set_meta("module_kind",source.kind)
  return group
 return null

func copy_tree(source: Node, parent: Node, owner_root: Node) -> void:
 for child in source.get_children():
  var copy := clone_node(child)
  if copy == null: continue
  # Godot's runtime-generated @names cannot be serialized; readable unique
  # names are assigned automatically by add_child(..., true).
  if child.get_script() == MODULE: copy.name = child.kind.to_pascal_case()
  elif not str(child.name).begins_with("@"): copy.name = child.name
  parent.add_child(copy,true)
  copy.owner = owner_root
  copy_tree(child,copy,owner_root)

func run() -> void:
 if FileAccess.file_exists(OUTPUT) and "--overwrite" not in OS.get_cmdline_user_args():
  print("Skipped existing layout; pass -- --overwrite to replace it.")
  quit()
  return
 var world: Node3D = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 var snapshot := Node3D.new()
 snapshot.name = "NeighborhoodLayout"
 # Copy only authored environment groups; exclude the live player, camera,
 # lighting and HUD. Gameplay remains in the original procedural scene.
 for child in world.get_children():
  if child.name not in ["GroundAndRoads","MapBoundaries","Crossings","01_StarterHouse","02_MotorcycleRepair","03_HuTieu","04_WetMarket","05_FoodStreet","06_FurnitureStore","07_PublicPark","08_School","09_ResidentialAlleys","10_ExpansionLot","StreetFurniture","NPCWalkingRoutes","NPCSpawnPoints"]: continue
  var group := clone_node(child)
  group.name = child.name
  snapshot.add_child(group,true)
  group.owner = snapshot
  copy_tree(child,group,snapshot)
 var packed := PackedScene.new()
 var error := packed.pack(snapshot)
 if error == OK: error = ResourceSaver.save(packed,OUTPUT)
 print("LAYOUT_BAKE_RESULT error=",error," groups=",snapshot.get_child_count())
 snapshot.free()
 world.free()
 quit(1 if error != OK else 0)
