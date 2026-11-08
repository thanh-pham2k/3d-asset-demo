extends SceneTree
# Captures the regular gameplay scene after programmatically pressing Start.
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("GameUI").start_game()
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 await process_frame
 var filename := "kenney-preview.png" if OS.get_environment("COUPLE_VISUAL") == "kenney" else "gameplay.png"
 root.get_texture().get_image().save_png("res://docs/screenshots/" + filename)
 scene.queue_free()
 await process_frame
 quit()
