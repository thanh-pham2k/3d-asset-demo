extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
 if value: print("PASS: ",label)
 else:
  failures += 1
  printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("GameUI").start_game()
 await create_timer(0.5).timeout
 var props = get_nodes_in_group("interactables")
 var player = get_first_node_in_group("players")
 var hammer = props.filter(func(n): return n is CharacterBody3D and n.get("prop_kind") == "hammer")[0]
 player.global_position = Vector3(0,0,1)
 player.facing = Vector3.RIGHT
 hammer.interact(player)
 Input.action_press("p1_swing")
 await create_timer(0.05).timeout
 Input.action_release("p1_swing")
 check(player.animation_controller.state == "hammer_swing", "hammer swing via input drives animation")
 hammer.throw_from(player)
 var chair = props.filter(func(n): return n is RigidBody3D and n.get("prop_kind") == "chair")[0]
 player.global_position = Vector3(-0.8,0,2.5)
 chair.global_position = Vector3(0,0.4,2.5)
 chair.linear_velocity = Vector3.ZERO
 chair.sleeping = false
 Input.action_press("p1_right")
 await create_timer(0.7).timeout
 Input.action_release("p1_right")
 check(chair.global_position.x > 0.08, "player pushes movable chair")
 var vase = props.filter(func(n): return n is RigidBody3D and n.get("prop_kind") == "vase")[0]
 vase.global_position = Vector3(0,2.2,2.4)
 vase.linear_velocity = Vector3(0,-6,0)
 vase.sleeping = false
 await create_timer(0.8).timeout
 check(not is_instance_valid(vase) or vase.broken, "vase breaks on physical impact")
 var boxes = props.filter(func(n): return is_instance_valid(n) and n is RigidBody3D and n.get("prop_kind") == "stack_box")
 check(boxes.size() == 2, "two stackable rigid boxes instantiated")
 boxes[0].global_position = Vector3(0,0.23,-2.7)
 boxes[1].global_position = Vector3(0,0.69,-2.7)
 for box in boxes:
  box.linear_velocity = Vector3.ZERO
  box.angular_velocity = Vector3.ZERO
  box.sleeping = false
 await create_timer(1.5).timeout
 var offset: Vector3 = boxes[1].global_position - boxes[0].global_position
 check(absf(offset.x) < 0.18 and absf(offset.z) < 0.18 and offset.y > 0.35, "stacked boxes remain supported")
 var kinds = ["cup","bottle","slipper","toy","container"]
 for kind in kinds:
  var item = get_nodes_in_group("interactables").filter(func(n): return n is RigidBody3D and n.get("prop_kind") == kind)[0]
  item.interact(player)
  check(item.held and item.freeze and player.held_pillow == item, kind + " pickup")
  item.throw_from(player)
  check(not item.held and not item.freeze and item.linear_velocity.length() > 1 and player.held_pillow == null, kind + " throw")
 await create_timer(1.5).timeout
 scene.queue_free()
 await process_frame
 print("PHYSICS_RESULT failures=",failures)
 quit(0 if failures == 0 else 1)
