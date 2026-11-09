extends SceneTree
# Render captures for visual review; no keyboard or hands-on input is simulated.
func _initialize() -> void:
 var scene = load("res://scenes/neighborhood.tscn").instantiate()
 root.add_child.call_deferred(scene)
 await create_timer(2.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-follow.png")
 scene.overview = true
 scene.camera.size = 330
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-actual.png")
 scene.overview = false
 scene.camera.size = 20
 scene.player.global_position = Vector3(-45,0.2,88)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-interior.png")
 scene.player.global_position = Vector3(-45,0.2,82)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-approach.png")
 scene.player.global_position = Vector3(-104,0.2,-13)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-garage.png")
 scene.player.global_position = Vector3(-50,0.2,-14)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-noodle.png")
 scene.player.global_position = Vector3(42,0.2,17)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-park-approach.png")
 scene.player.global_position = Vector3(42,0.2,60)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-park.png")
 scene.player.global_position = Vector3(38,0.2,-26)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-market.png")
 scene.player.global_position = Vector3(-105,0.2,35)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-grocery.png")
 scene.player.global_position = Vector3(104,0.2,-19)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-furniture.png")
 scene.player.global_position = Vector3(105,0.2,-46)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-school.png")
 scene.player.global_position = Vector3(-53,0.2,-90)
 await create_timer(1.0).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://docs/screenshots/neighborhood-residential.png")
 quit()
