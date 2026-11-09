extends SceneTree
# Check a player-sized swept corridor across every generated building doorway.
const MODULE := preload("res://scripts/neighborhood/module.gd")
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var world = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 await physics_frame
 var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
 var shape := CapsuleShape3D.new()
 shape.radius = 0.32
 shape.height = 1.0
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = shape
 query.collision_mask = 1
 var count := 0
 for module in world.find_children("*", "Node3D", true, false):
  if module.get_script() != MODULE or module.interior_half_size == Vector2.ZERO: continue
  count += 1
  var edge: float = -module.interior_half_size.y - 0.25
  var outside: Vector3 = module.to_global(Vector3(0,0.65,edge-2.0))
  var inside: Vector3 = module.to_global(Vector3(0,0.65,edge+1.5))
  query.transform = Transform3D(Basis.IDENTITY,outside)
  query.motion = inside-outside
  var clear: bool = space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0] > 0.999
  var player = world.player
  player.global_position = module.to_global(Vector3(0,0.2,0))
  module._process(0.0)
  var hidden := true
  for mesh in module.cutaway_meshes: hidden = hidden and not mesh.visible
  player.global_position = Vector3(-120,0.2,120)
  module._process(0.0)
  var restored := true
  for mesh in module.cutaway_meshes: restored = restored and mesh.visible
  if not hidden or not restored:
   failures += 1
   printerr("FAIL: cutaway cycle ",module.kind," at ",module.global_position)
  if not clear:
   failures += 1
   printerr("FAIL: ",module.kind," entrance at ",module.global_position," outside ",outside)
  else: print("PASS: ",module.kind," entrance at ",module.global_position)
 if count == 0:
  failures += 1
  printerr("FAIL: no buildings checked")
 print("ENTRANCE_RESULT buildings=",count," failures=",failures)
 quit(1 if failures else 0)
