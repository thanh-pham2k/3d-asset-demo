extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
 if ok: print("PASS: ", label)
 else:
  failures += 1
  printerr("FAIL: ", label)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 var player = game.p1
 var ui = game.get_node("GameUI")
 var room = game.get_node("Room")
 var world = game.get_node("Neighborhood")
 player.select_character("girl")
 ui.start_game()
 await physics_frame
 check(get_nodes_in_group("players").size() == 1 and world.player == null, "one player in the connected world")
 check(player.animation_controller.model.variant_override == 2, "selected girl remains active")
 var guidance = game.get_node("WorkplaceGuidance")
 await process_frame
 await process_frame
 check(guidance.direction.text.contains("Quán hủ tiếu") and guidance.direction.text.contains("m"), "girl receives direction and distance to noodle shop")
 player.select_character("boy")
 await process_frame
 check(guidance.direction.text.contains("Tiệm sửa xe"), "boy receives direction to repair shop")
 player.select_character("girl")
 var door = room.current_door
 var body = door.get_meta("door_body")
 check(body.collision_layer == 1, "closed door blocks the opening")
 player.global_position = game.to_global(Vector3(0, 0.05, -3.5))
 player.velocity = Vector3.ZERO
 await physics_frame
 player.find_target()
 check(player.target == door and player.prompt_label.text.contains("Mở cửa"), "door is targeted with open prompt")
 Input.action_press("p1_interact")
 await physics_frame
 await physics_frame
 Input.action_release("p1_interact")
 await physics_frame
 check(body.collision_layer == 0, "open door clears collision")
 player.global_position = game.to_global(Vector3(0, 0.05, -3.1))
 player.velocity = Vector3.ZERO
 Input.action_press("p1_up")
 for i in range(100): await physics_frame
 Input.action_release("p1_up")
 check(game.to_local(player.global_position).z < -4.9, "walked outside through doorway")
 Input.action_press("p1_down")
 for i in range(100): await physics_frame
 Input.action_release("p1_down")
 check(game.to_local(player.global_position).z > -4.0, "walked back inside through same doorway")
 check(player.animation_controller.model.variant_override == 2, "character persists after return")
 door.interact(player)
 await physics_frame
 await physics_frame
 check(body.collision_layer == 1, "door closes again")
 check(world.get_node("GarageBusiness").global_position.x == 42.0, "garage stations moved with the shop")
 player.global_position = guidance.NOODLE
 player.velocity = Vector3.ZERO
 await process_frame
 await process_frame
 check(guidance.arrived and guidance.direction.text.contains("Tương tác") and not guidance.marker.visible, "arrival replaces direction with interaction guidance")
 check(world.get_node("EconomyManager").house_manager == room, "house and businesses use shared economy")
 game.queue_free()
 await process_frame
 print("OPEN_WORLD_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
