extends SceneTree
var events: Array[String] = []
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func record(event_name: String, _position: Vector3) -> void:
 events.append(event_name)
func check(value: bool, label: String) -> void:
 if value: print("PASS: ", label)
 else:
  failures += 1
  printerr("FAIL: ", label)
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("GameUI").start_game()
 var player = get_first_node_in_group("players")
 var fx = get_first_node_in_group("chaos_feedback")
 fx.event_played.connect(record)
 var target = load("res://tests/feedback_target.gd").new()
 target.position = Vector3(1.9, 0, 2)
 scene.add_child(target)
 await create_timer(0.15).timeout
 for kind in ["pillow", "hammer"]:
  var prop = get_nodes_in_group("interactables").filter(func(n): return n is CharacterBody3D and n.get("prop_kind") == kind)[0]
  target.was_hit = false
  events.clear()
  player.position = Vector3(0,0,2)
  player.velocity = Vector3.ZERO
  player.facing = Vector3.RIGHT
  player.visual.rotation.y = PI / 2
  prop.position = Vector3(0.3,0.2,2)
  prop.pickup_timer = 0.0
  prop.interact(player)
  await process_frame
  prop.throw_from(player)
  await create_timer(0.5).timeout
  check(target.was_hit and events.has("bonk" if kind == "hammer" else "pillow_impact"), kind + " collision emits correct hit cue")
  await create_timer(1.0).timeout
  prop.position = Vector3(-7, 0.2, 3)
  prop.collision_layer = 0
 target.queue_free()
 scene.queue_free()
 await process_frame
 print("FEEDBACK_HIT_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
