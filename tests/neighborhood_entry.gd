extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room = load("res://scenes/main.tscn").instantiate()
 root.add_child(room)
 current_scene = room
 var ui = room.get_node("GameUI")
 if not paused:
  printerr("FAIL: room menu did not pause")
  quit(1)
  return
 ui.open_neighborhood()
 await process_frame
 await process_frame
 if current_scene == null or current_scene.scene_file_path != "res://scenes/neighborhood.tscn" or paused:
  printerr("FAIL: neighborhood menu transition")
  quit(1)
  return
 print("PASS: menu opens an unpaused neighborhood")
 var esc := InputEventKey.new()
 esc.keycode = KEY_ESCAPE
 esc.pressed = true
 current_scene._input(esc)
 await process_frame
 await process_frame
 if current_scene == null or current_scene.scene_file_path != "res://scenes/main.tscn" or not paused:
  printerr("FAIL: return to room menu")
  quit(1)
  return
 print("PASS: Escape returns to room menu")
 quit(0)
