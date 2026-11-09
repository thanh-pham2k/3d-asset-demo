extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var world = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 await physics_frame
 var crossings = world.get_node("Crossings")
 var positions := {}
 var failures := 0
 for c in crossings.get_children():
  var key := Vector2i(roundi(c.position.x),roundi(c.position.z))
  positions[key] = true
  if not c.find_children("*", "CollisionShape3D", true, false).is_empty():
   printerr("FAIL: crossing has collision at ",key)
   failures += 1
 for x in [-80,0,80]:
  for side in [-1,1]:
   for pos in [Vector2i(x+side*6,0),Vector2i(x,side*8),Vector2i(x+side*6,-54),Vector2i(x,-54+side*4)]:
    if not positions.has(pos):
     printerr("FAIL: missing crossing at ",pos)
     failures += 1
 if crossings.get_child_count() != 30:
  printerr("FAIL: expected 30 crossing modules, got ",crossings.get_child_count())
  failures += 1
 print("CROSSINGS_RESULT modules=",crossings.get_child_count()," failures=",failures)
 quit(1 if failures else 0)
