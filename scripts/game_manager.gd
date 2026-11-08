extends Node3D

func _ready() -> void:
 setup_input()
 var feedback = preload("res://scripts/effects/chaos_feedback.gd").new()
 feedback.add_to_group("chaos_feedback")
 add_child(feedback)
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
 # Optional visual preview uses the same player and gameplay interface.
 if OS.get_environment("COUPLE_VISUAL") == "kenney":
  p1.config.visual_scene = load("res://scenes/characters/kenney_boy_visual.tscn")
 p1.position = Vector3(0,0,1.0)
 add_child(p1)
 var pillow = preload("res://scenes/pillow.tscn").instantiate()
 pillow.position = Vector3(1.2,0.2,0.8)
 add_child(pillow)
 # Prototype props share the same pickup and throw behavior as the pillow.
 for data in [["hammer", Vector3(1.8,0.25,1.5)], ["bear", Vector3(-3.8,0.25,1.5)], ["box", Vector3(2.4,0.25,-2.2)], ["book", Vector3(-4.0,0.25,-2.4)], ["ball", Vector3(3.0,0.25,1.8)]]:
  var prop = load("res://scenes/props/%s.tscn" % data[0]).instantiate()
  prop.position = data[1]
  add_child(prop)
 for data in [["chair",Vector3(2.8,0.5,-0.8)], ["vase",Vector3(3.5,0.25,-2.6)], ["cup",Vector3(3.6,0.3,2.8)], ["bottle",Vector3(4.1,0.4,2.8)], ["slipper",Vector3(-4.5,0.2,1.1)], ["toy",Vector3(-3.4,0.2,2.2)], ["container",Vector3(1.4,0.25,2.8)], ["stack_box",Vector3(2.1,0.23,2.8)], ["stack_box",Vector3(2.1,0.68,2.8)]]:
  var prop = preload("res://scripts/physics_prop.gd").new()
  prop.prop_kind = data[0]
  prop.position = data[1]
  add_child(prop)
 var camera = Camera3D.new()
 camera.set_script(load("res://scripts/shared_camera.gd"))
 camera.players = [p1]
 add_child(camera)
 var ui = preload("res://scripts/game_ui.gd").new()
 ui.name = "GameUI"
 ui.player = p1
 add_child(ui)

func setup_input() -> void:
 var bindings = {
  "p1_left":KEY_A, "p1_right":KEY_D, "p1_up":KEY_W, "p1_down":KEY_S, "p1_interact":KEY_E, "p1_throw":KEY_F, "p1_dash":KEY_SPACE, "p1_swing":KEY_Q,

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

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_F11:
   var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
