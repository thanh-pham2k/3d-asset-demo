extends Node3D

func _ready() -> void:
 setup_input()
 var env = WorldEnvironment.new()
 var environment = Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color("bdd1c9")
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("fff0dd")
 environment.ambient_light_energy = 0.4
 environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 env.environment = environment
 add_child(env)
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-35,0)
 sun.light_energy = 0.45
 sun.shadow_enabled = true
 add_child(sun)
 var room = preload("res://scenes/room.tscn").instantiate()
 add_child(room)
 var p1 = preload("res://scenes/player.tscn").instantiate()
 p1.player_id = 1
 p1.position = Vector3(0,0,1.0)
 add_child(p1)
 var pillow = preload("res://scenes/pillow.tscn").instantiate()
 pillow.position = Vector3(1.2,0.2,0.8)
 add_child(pillow)
 var camera = Camera3D.new()
 camera.set_script(load("res://scripts/shared_camera.gd"))
 camera.players = [p1]
 add_child(camera)
 setup_hud()

func setup_input() -> void:
 var bindings = {
  "p1_left":KEY_A, "p1_right":KEY_D, "p1_up":KEY_W, "p1_down":KEY_S, "p1_interact":KEY_E, "p1_throw":KEY_F, "p1_dash":KEY_SPACE,

 }
 for action in bindings:
  if not InputMap.has_action(action): InputMap.add_action(action)
  var event = InputEventKey.new()
  event.physical_keycode = bindings[action]
  InputMap.action_add_event(action,event)
 for i in [1]:
  var action = "p%d_run" % i
  if not InputMap.has_action(action): InputMap.add_action(action)
  var event = InputEventKey.new()
  event.keycode = KEY_SHIFT
  event.location = KEY_LOCATION_LEFT if i == 1 else KEY_LOCATION_RIGHT
  InputMap.action_add_event(action,event)

func setup_hud() -> void:
 var canvas = CanvasLayer.new()
 add_child(canvas)
 var left = Label.new()
 left.text = "♥  WASD · E tương tác · F ném · Space lướt · Shift chạy"
 left.position = Vector2(24,20)
 left.add_theme_font_size_override("font_size", 20)
 left.add_theme_color_override("font_color",Color("543e3c"))
 canvas.add_child(left)
 var restart = Button.new()
 restart.text = "↻  Restart"
 restart.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 restart.position = Vector2(-100,18)
 restart.pressed.connect(func(): get_tree().reload_current_scene())
 canvas.add_child(restart)

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE:
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  elif event.keycode == KEY_F11:
   var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
