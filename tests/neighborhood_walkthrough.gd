extends SceneTree
# Automated InputMap traversal: accelerated simulation, not physical keyboard QA.
# A conservative grid plans routes; the actual CharacterBody moves without teleporting.
const STEP := 2.0
const LIMIT := 61
var space: PhysicsDirectSpaceState3D
var query := PhysicsShapeQueryParameters3D.new()
var cache := {}
var edge_cache := {}
var player: CharacterBody3D

func _initialize() -> void:
 call_deferred("run")

func point(cell: Vector2i) -> Vector3:
 return Vector3(cell.x*STEP,0.65,cell.y*STEP)

func available(cell: Vector2i) -> bool:
 if absi(cell.x) > LIMIT or absi(cell.y) > LIMIT: return false
 if cache.has(cell): return cache[cell]
 query.transform = Transform3D(Basis.IDENTITY,point(cell))
 query.motion = Vector3.ZERO
 var result := space.intersect_shape(query,1).is_empty()
 cache[cell] = result
 return result

func link_clear(a: Vector2i, b: Vector2i) -> bool:
 var key := str(a) + ":" + str(b)
 if edge_cache.has(key): return edge_cache[key]
 query.transform = Transform3D(Basis.IDENTITY,point(a))
 query.motion = point(b)-point(a)
 var clear := space.cast_motion(query)[0] > 0.999
 edge_cache[key] = clear
 return clear

func route(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
 var queue: Array[Vector2i] = [start]
 var previous := {start:start}
 var cursor := 0
 while cursor < queue.size() and not previous.has(goal):
  var at := queue[cursor]
  cursor += 1
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i = at + direction
   if previous.has(next) or not available(next) or not link_clear(at,next): continue
   previous[next] = at
   queue.append(next)
 var result: Array[Vector2i] = []
 if not previous.has(goal): return result
 var node := goal
 while node != start:
  result.push_front(node)
  node = previous[node]
 return result

func release_inputs() -> void:
 for action in ["p1_left","p1_right","p1_up","p1_down","p1_run"]: Input.action_release(action)

func set_axis(negative: String, positive: String, error: float) -> void:
 Input.action_release(negative)
 Input.action_release(positive)
 if error < -0.13: Input.action_press(negative)
 elif error > 0.13: Input.action_press(positive)

func walk_to(target: Vector2) -> bool:
 var previous := Vector2(player.global_position.x,player.global_position.z)
 var stuck := 0
 for frame in range(420):
  var current := Vector2(player.global_position.x,player.global_position.z)
  var diff := target-current
  if diff.length() < 0.22:
   release_inputs()
   return true
  set_axis("p1_left","p1_right",diff.x)
  set_axis("p1_up","p1_down",diff.y)
  Input.action_press("p1_run")
  await physics_frame
  var after := Vector2(player.global_position.x,player.global_position.z)
  if after.distance_to(previous) < 0.004: stuck += 1
  else: stuck = 0
  if stuck > 90:
   printerr("STUCK at ",after," toward ",target)
   release_inputs()
   return false
  previous = after
 printerr("TIMEOUT at ",player.global_position," toward ",target)
 release_inputs()
 return false

func run() -> void:
 Engine.physics_ticks_per_second = 240
 Engine.time_scale = 4.0
 var world = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 await physics_frame
 player = world.player
 space = world.get_world_3d().direct_space_state
 var shape := CapsuleShape3D.new()
 shape.radius = 0.32
 shape.height = 1.0
 query.shape = shape
 query.collision_mask = 1
 var current := Vector2i(-22,35)
 if not await walk_to(Vector2(current.x*STEP,current.y*STEP)):
  printerr("FAIL: align with first grid cell")
  quit(1)
  return
 var targets := [
  ["starter yard",Vector2i(-22,35)], ["starter house interior",Vector2i(-22,44)],
  ["food street",Vector2i(-50,6)], ["grocery interior",Vector2i(-52,17)],
  ["garage interior",Vector2i(-52,-9)], ["noodle shop",Vector2i(-25,-6)],
  ["market",Vector2i(19,-7)], ["furniture store interior",Vector2i(52,-10)],
  ["school interior",Vector2i(52,-47)], ["residential alley",Vector2i(5,-29)],
  ["park",Vector2i(21,13)], ["expansion lot",Vector2i(52,15)]
 ]
 for target in targets:
  var goal: Vector2i = target[1]
  if not available(goal):
   printerr("FAIL: target blocked ",target[0])
   quit(1)
   return
  var path := route(current,goal)
  if path.is_empty() and current != goal:
   printerr("FAIL: no route to ",target[0])
   quit(1)
   return
  for cell in path:
   if not await walk_to(Vector2(cell.x*STEP,cell.y*STEP)):
    printerr("FAIL: controller traversal to ",target[0]," near ",cell)
    quit(1)
    return
  current = goal
  print("PASS: controller reached ",target[0]," via ",path.size()," grid steps")
 release_inputs()
 print("WALKTHROUGH_RESULT failures=0")
 quit()
