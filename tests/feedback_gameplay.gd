extends SceneTree
var events: Array[String] = []
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, label: String) -> void:
 if value: print("PASS: ", label)
 else:
  failures += 1
  printerr("FAIL: ", label)

func capture(event_name: String, _position: Vector3) -> void:
 events.append(event_name)

func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("GameUI").start_game()
 var feedback = get_first_node_in_group("chaos_feedback")
 feedback.event_played.connect(capture)
 var player = get_first_node_in_group("players")
 var pillow = get_nodes_in_group("interactables").filter(func(item): return item is CharacterBody3D and item.get("prop_kind") == "pillow")[0]
 await create_timer(0.2).timeout
 player.global_position = Vector3(0,0,1)
 pillow.global_position = Vector3(0.4,0.2,1)
 player.facing = Vector3.RIGHT
 pillow.interact(player)
 check(events.has("pickup"), "pickup emits feedback from gameplay")
 pillow.throw_from(player)
 check(events.has("throw"), "throw emits feedback from gameplay")
 await create_timer(1.3).timeout
 check(events.has("throw_trail"), "flying prop emits trail feedback")
 check(events.has("landing"), "thrown prop landing emits feedback")
 check(pillow.state == pillow.State.IDLE, "thrown prop is recoverable")
 pillow.interact(player)
 pillow.drop_from(player)
 check(events.has("drop"), "drop emits feedback from gameplay")
 player.hit(Vector3.RIGHT)
 check(events.has("hit") and events.has("hit_stars"), "player hit emits sound and stars")
 player.global_position = Vector3(0,0,2)
 Input.action_press("p1_right")
 await create_timer(0.8).timeout
 Input.action_release("p1_right")
 check(events.has("footstep"), "movement emits footsteps")
 await create_timer(1.5).timeout
 check(feedback.get_child_count() == 0, "gameplay feedback nodes clean up")
 scene.queue_free()
 await process_frame
 print("FEEDBACK_GAMEPLAY failures=", failures)
 quit(0 if failures == 0 else 1)
