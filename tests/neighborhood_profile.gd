extends SceneTree
# Staged renderer sample, intended for a windowed local run. Not a benchmark
# for other GPUs or a substitute for an interactive play test.
func _initialize() -> void:
 call_deferred("run")

func sample(label: String) -> void:
 var deltas: Array[float] = []
 var start := Time.get_ticks_usec()
 var prev := start
 for i in range(180):
  await process_frame
  var now := Time.get_ticks_usec()
  if i >= 30: deltas.append((now-prev)/1000.0)
  prev = now
 deltas.sort()
 print("PROFILE ",label," samples=",deltas.size()," median_ms=",deltas[deltas.size()/2]," p95_ms=",deltas[int(deltas.size()*0.95)]," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func run() -> void:
 var world = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 await create_timer(1.0).timeout
 await sample("follow")
 world.overview = true
 world.camera.size = 330
 await create_timer(1.0).timeout
 await sample("overview")
 quit()
