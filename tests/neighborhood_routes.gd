extends SceneTree
# Verify that guide intersections are explicit shared curve points.
var failures := 0
func check(ok: bool, message: String) -> void:
 if ok: print("PASS: ",message)
 else:
  failures += 1
  printerr("FAIL: ",message)
func _initialize() -> void:
 call_deferred("run")
func key(p: Vector3) -> Vector2i:
 return Vector2i(roundi(p.x*100),roundi(p.z*100))
func run() -> void:
 var world = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 var routes: Node = world.get_node("NPCWalkingRoutes")
 var graph := {}
 for path in routes.get_children():
  check(path.curve.point_count >= 2, path.name + " has at least two points")
  var last := key(path.to_global(path.curve.get_point_position(0)))
  if not graph.has(last): graph[last] = []
  for i in range(1,path.curve.point_count):
   var current := key(path.to_global(path.curve.get_point_position(i)))
   if not graph.has(current): graph[current] = []
   graph[last].append(current)
   graph[current].append(last)
   last = current
 var queue: Array[Vector2i] = [graph.keys()[0]]
 var reached := {queue[0]:true}
 var cursor := 0
 while cursor < queue.size():
  var node := queue[cursor]
  cursor += 1
  for neighbor in graph[node]:
   if reached.has(neighbor): continue
   reached[neighbor] = true
   queue.append(neighbor)
 check(reached.size() == graph.size(), "all guide segments form one shared-point network")
 for path_name in ["NorthLocalSidewalk","SouthLocalNorth","SouthLocalSouth","ResidentialAlley","ParkPromenade"]:
  check(routes.has_node(path_name), "named guide exists: " + path_name)
 var north: Path3D = routes.get_node("NorthLocalSidewalk")
 check(is_equal_approx(north.curve.get_point_position(0).z,-58.0), "north local guide follows sidewalk instead of road centre")
 var park: Path3D = routes.get_node("ParkPromenade")
 check(park.curve.point_count >= 2 and reached.has(key(park.to_global(park.curve.get_point_position(0)))), "park promenade joins sidewalk network")
 print("ROUTE_GRAPH_RESULT points=",graph.size()," failures=",failures)
 quit(1 if failures else 0)
