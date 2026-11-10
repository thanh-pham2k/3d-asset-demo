extends SceneTree
# Samples a conservative player-sized footprint and sweeps each grid edge against
# actual physics shapes. This checks routes, not keyboard or human play.
var failures := 0
var space: PhysicsDirectSpaceState3D
var capsule := CapsuleShape3D.new()
var query := PhysicsShapeQueryParameters3D.new()
const MIN_CELL := -61
const MAX_CELL := 61
const STEP := 2.0

func check(ok: bool, label: String) -> void:
 if ok: print("PASS: ", label)
 else:
  failures += 1
  printerr("FAIL: ", label)

func _initialize() -> void:
 call_deferred("run")

func point(cell: Vector2i) -> Vector3:
 return Vector3(cell.x * STEP, 0.65, cell.y * STEP)

func free_at(cell: Vector2i) -> bool:
 query.transform = Transform3D(Basis.IDENTITY, point(cell))
 query.motion = Vector3.ZERO
 return space.intersect_shape(query, 1).is_empty()

func edge_clear(a: Vector2i, b: Vector2i) -> bool:
 query.transform = Transform3D(Basis.IDENTITY, point(a))
 query.motion = point(b) - point(a)
 var result := space.cast_motion(query)
 return result[0] > 0.999

func run() -> void:
 var world = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await physics_frame
 await physics_frame
 space = world.get_world_3d().direct_space_state
 capsule.radius = 0.32 # wider than the player's 0.23 m capsule
 capsule.height = 1.0
 query.shape = capsule
 query.collision_mask = 1
 var start := Vector2i(-22,35)
 var reachable := {start:true}
 var blocked := {}
 var queue: Array[Vector2i] = [start]
 var cursor := 0
 while cursor < queue.size():
  var cell := queue[cursor]
  cursor += 1
  for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i = cell + delta
   if next.x < MIN_CELL or next.x > MAX_CELL or next.y < MIN_CELL or next.y > MAX_CELL: continue
   if reachable.has(next) or blocked.has(next): continue
   if not free_at(next):
    blocked[next] = true
    continue
   if edge_clear(cell,next):
    reachable[next] = true
    queue.append(next)
 print("Reachable 2 m cells: ", reachable.size())
 var targets := {
  "starter house interior":Vector2i(-22,44), "garage interior":Vector2i(-31,-9),
  "noodle shop":Vector2i(-25,-6), "wet market":Vector2i(19,-7),
  "food street":Vector2i(-50,6), "grocery interior":Vector2i(-52,17),
  "furniture store interior":Vector2i(52,-10), "park":Vector2i(21,13),
  "school interior":Vector2i(52,-47), "residential alley":Vector2i(5,-29),
  "expansion lot":Vector2i(52,15)
 }
 for label in targets:
  check(reachable.has(targets[label]), "connected route to " + label)
 # Each exterior doorway must connect to the spawn-reachable grid, not just
 # have a clear doorway in isolation. Test a short continuous sweep to it.
 var module_script = load("res://scripts/neighborhood/module.gd")
 var entrance_count := 0
 for module in world.find_children("*", "Node3D", true, false):
  if module.get_script() != module_script or module.interior_half_size == Vector2.ZERO: continue
  entrance_count += 1
  var door_z: float = -module.interior_half_size.y - 0.25 - 2.0
  var outside: Vector3 = module.to_global(Vector3(0,0.65,door_z))
  var grid_x := int(round(outside.x / STEP))
  var grid_z := int(round(outside.z / STEP))
  var connected := false
  for dx in range(-1,2):
   for dz in range(-1,2):
    var cell := Vector2i(grid_x+dx,grid_z+dz)
    if not reachable.has(cell): continue
    query.transform = Transform3D(Basis.IDENTITY, point(cell))
    query.motion = outside-point(cell)
    if space.cast_motion(query)[0] > 0.999: connected = true
  check(connected, "reachable entrance: " + str(module.global_position))
 check(entrance_count >= 31, "all building entrances sampled")
 for cell in [Vector2i(23,33),Vector2i(31,33),Vector2i(27,29),Vector2i(27,37)]:
  check(reachable.has(cell), "park route around pond: " + str(cell))
 for spec in [["pond",Vector3(46,0.65,66),Vector3(8,0,0)], ["tree trunk",Vector3(-117,0.65,-10),Vector3(2,0,0)], ["planter",Vector3(-58,0.65,76),Vector3(2,0,0)]]:
  query.transform = Transform3D(Basis.IDENTITY,spec[1])
  query.motion = spec[2]
  check(space.cast_motion(query)[0] < 0.999, spec[0] + " blocks a player-sized sweep")
 var disabled_pond = load("res://scenes/neighborhood/pond.tscn").instantiate()
 disabled_pond.collision_enabled = false
 root.add_child(disabled_pond)
 check(disabled_pond.find_children("*", "StaticBody3D", true, false).is_empty(), "module collision can be disabled per instance")
 disabled_pond.free()
 query.transform = Transform3D(Basis.IDENTITY, Vector3(-49.3,0.65,88))
 query.motion = Vector3.ZERO
 check(not space.intersect_shape(query, 1).is_empty(), "house side wall is solid")
 # A physics sweep checks the actual boundary rather than only the sampled grid.
 for boundary in [["east",Vector3(123,0.65,0),Vector3(4,0,0)],["west",Vector3(-123,0.65,0),Vector3(-4,0,0)],["north",Vector3(0,0.65,-123),Vector3(0,0,-4)],["south",Vector3(0,0.65,123),Vector3(0,0,4)]]:
  query.transform = Transform3D(Basis.IDENTITY, boundary[1])
  query.motion = boundary[2]
  check(space.cast_motion(query)[0] < 1.0, boundary[0] + " map boundary blocks a player-sized body")
 # Yard fences block through-traffic, while two deliberately wide gaps connect it.
 for spec in [["front",Vector3(-45,0.65,59),Vector3(0,0,8)],["side",Vector3(-70,0.65,85),Vector3(8,0,0)]]:
  query.transform = Transform3D(Basis.IDENTITY,spec[1])
  query.motion = spec[2]
  check(space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0] > 0.999, "starter yard " + spec[0] + " opening remains clear")
 query.transform = Transform3D(Basis.IDENTITY,Vector3(-56,0.65,59))
 query.motion = Vector3(0,0,8)
 check(space.cast_motion(query)[0] < 0.999, "starter yard fence rail blocks passage")
 # Store displays are independent modules with their own collisions.
 var display_kinds := {}
 for display in world.get_node("06_FurnitureStore").get_children():
  if display.get_script() == module_script and display.kind in ["sofa","bed","television","refrigerator","coffee_table"]:
   display_kinds[display.kind] = true
   check(not display.find_children("*", "CollisionShape3D", true, false).is_empty(), "store display collision: " + display.kind)
 check(display_kinds.size() == 5, "store has five independent furniture and appliance modules")
 # School gate columns are solid while the centre remains a clear approach.
 query.transform = Transform3D(Basis.IDENTITY, Vector3(105,0.65,-46))
 query.motion = Vector3(0,0,-8)
 check(space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0] > 0.999, "school gate centre remains open")
 query.transform = Transform3D(Basis.IDENTITY, Vector3(99,0.65,-46))
 query.motion = Vector3(0,0,-8)
 check(space.cast_motion(query)[0] < 0.999, "school gate column is solid")
 var spawns = world.get_node("NPCSpawnPoints")
 check(spawns.get_child_count() == 10, "NPC spawn markers exist for all districts")
 for marker in spawns.get_children():
  query.transform = Transform3D(Basis.IDENTITY, marker.global_position + Vector3.UP * 0.65)
  query.motion = Vector3.ZERO
  check(space.intersect_shape(query, 1).is_empty(), "NPC spawn clear: " + marker.name)
 var routes = world.get_node("NPCWalkingRoutes")
 check(routes.get_child_count() >= 7, "NPC guide paths include local streets")
 for route in routes.get_children():
  for i in range(route.curve.point_count - 1):
   var a: Vector3 = route.to_global(route.curve.get_point_position(i)) + Vector3.UP * 0.65
   var b: Vector3 = route.to_global(route.curve.get_point_position(i + 1)) + Vector3.UP * 0.65
   query.transform = Transform3D(Basis.IDENTITY, a)
   query.motion = b - a
   check(space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0] > 0.999, "NPC guide path clear: " + route.name)
 var player = world.player
 var initial: Vector3 = player.global_position
 Input.action_press("p1_right")
 await create_timer(0.5).timeout
 Input.action_release("p1_right")
 check(player.global_position.x > initial.x + 0.3, "existing player moves via InputMap")
 check(not world.overview and world.camera.size == 20, "play starts in follow view")
 var house = world.get_node("01_StarterHouse").get_child(2)
 # Identify the module by its script, independent of the ground and path meshes.
 for child in world.get_node("01_StarterHouse").get_children():
  if child.get_script() == load("res://scripts/neighborhood/module.gd") and child.kind == "house": house = child
 player.global_position = Vector3(-45,0.2,88)
 await process_frame
 await process_frame
 check(not house.cutaway_meshes[0].visible, "building shell hides while player is inside")
 query.transform = Transform3D(Basis.IDENTITY, Vector3(-49.3,0.65,88))
 query.motion = Vector3.ZERO
 check(not space.intersect_shape(query, 1).is_empty(), "cutaway retains wall collision")
 player.global_position = Vector3(-45,0.2,70)
 await process_frame
 await process_frame
 check(house.cutaway_meshes[0].visible, "building shell returns after exit")
 # Exterior line of sight, orthographic overview, and collisions are distinct.
 player.global_position = Vector3(-45,0.2,82)
 house._process(0.0)
 var exterior_hidden := true
 for visual in house.cutaway_meshes: exterior_hidden = exterior_hidden and not visual.visible
 check(exterior_hidden, "house shell hides when it blocks exterior camera view")
 query.transform = Transform3D(Basis.IDENTITY, Vector3(-49.3,0.65,88))
 query.motion = Vector3.ZERO
 check(not space.intersect_shape(query,1).is_empty(), "exterior camera cutaway retains collision")
 player.global_position = Vector3(-34,0.2,82)
 house._process(0.0)
 var clear_visible := true
 for visual in house.cutaway_meshes: clear_visible = clear_visible and visual.visible
 check(clear_visible, "house shell remains visible outside the camera ray")
 player.global_position = Vector3(-45,0.2,88)
 world.camera.size = 330
 house._process(0.0)
 var map_visible := true
 for visual in house.cutaway_meshes: map_visible = map_visible and visual.visible
 check(map_visible, "overview shows complete building even when player is inside")
 world.camera.size = 20
 var rotated_house = null
 for module in world.get_node("09_ResidentialAlleys").get_children():
  if module.get_script() == module_script and module.kind == "house" and absf(module.rotation.y) > 1.0 and absf(module.rotation.y) < 2.0:
   rotated_house = module
   break
 check(rotated_house != null, "rotated house exists for side-wall cutaway check")
 if rotated_house:
  player.global_position = rotated_house.global_position
  rotated_house._process(0.0)
  var sides_hidden := true
  for wall in rotated_house.side_cutaway_meshes: sides_hidden = sides_hidden and not wall.visible
  check(not rotated_house.side_cutaway_meshes.is_empty() and sides_hidden, "camera-facing side walls hide inside rotated houses")
  world.camera.size = 330
  rotated_house._process(0.0)
  var sides_visible := true
  for wall in rotated_house.side_cutaway_meshes: sides_visible = sides_visible and wall.visible
  check(sides_visible, "map view restores rotated-house side walls")
 world.camera.size = 20
 player.global_position = Vector3(-45,0.2,70)
 var toggle := InputEventKey.new()
 toggle.keycode = KEY_TAB
 toggle.pressed = true
 world._unhandled_key_input(toggle)
 check(world.overview and world.camera.size == 330, "Tab opens overview")
 world._unhandled_key_input(toggle)
 check(not world.overview and world.camera.size == 20, "Tab returns to follow view")
 world.queue_free()
 print("NEIGHBORHOOD_RESULT failures=", failures)
 quit(1 if failures else 0)
