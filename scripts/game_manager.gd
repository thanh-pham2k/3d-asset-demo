extends Node3D

var score_manager: Node
var challenge_manager: Node
var round_manager: Node
var mission_manager: Node
var p1: CharacterBody3D
var p2: CharacterBody3D
var coop_manager: CoopManager
var main_camera: Camera3D
var is_coop: bool = false

func _ready() -> void:
 position = Vector3(-45, 0, 88)
 setup_input()
 var feedback = preload("res://scripts/effects/chaos_feedback.gd").new()
 feedback.add_to_group("chaos_feedback")
 add_child(feedback)
 
 const ScoreManagerScript = preload("res://scripts/score_manager.gd")
 const ChallengeManagerScript = preload("res://scripts/challenge_manager.gd")
 const RoundManagerScript = preload("res://scripts/round_manager.gd")
 const MissionManagerScript = preload("res://scripts/cleaning/mission_manager.gd")
 const PlacementZoneScript = preload("res://scripts/cleaning/placement_zone.gd")
 const HazardBananaScript = preload("res://scripts/cleaning/hazard_banana.gd")
 const GameUIScript = preload("res://scripts/game_ui.gd")
 
 score_manager = ScoreManagerScript.new()
 score_manager.name = "ScoreManager"
 add_child(score_manager)
 
 challenge_manager = ChallengeManagerScript.new()
 challenge_manager.name = "ChallengeManager"
 add_child(challenge_manager)
 
 round_manager = RoundManagerScript.new()
 round_manager.name = "RoundManager"
 round_manager.round_duration = 60.0
 add_child(round_manager)
 round_manager.call("setup", score_manager, challenge_manager)
 
 mission_manager = MissionManagerScript.new()
 mission_manager.name = "MissionManager"
 add_child(mission_manager)
 
 var room = preload("res://scenes/room.tscn").instantiate()
 add_child(room)
 p1 = preload("res://scenes/player.tscn").instantiate()
 p1.player_id = 1
 # Optional visual preview uses the same player and gameplay interface.
 if OS.get_environment("COUPLE_VISUAL") == "kenney":
  p1.config.visual_scene = load("res://scenes/characters/kenney_boy_visual.tscn")
 p1.position = Vector3(0,0,1.0)
 add_child(p1)
 p1.select_character("boy")
 var neighborhood = preload("res://scenes/neighborhood.tscn").instantiate()
 neighborhood.name = "Neighborhood"
 neighborhood.integrated = true
 neighborhood.position = -position
 add_child(neighborhood)
 
 var pillow = preload("res://scenes/pillow.tscn").instantiate()
 pillow.position = Vector3(1.2,0.2,0.8)
 add_child(pillow)
 # The 5 other CharacterBody3D props (preserving 6 total for smoke checks)
 for data in [["hammer", Vector3(1.8,0.25,1.5)], ["bear", Vector3(-3.8,0.25,1.5)], ["box", Vector3(2.4,0.25,-2.2)], ["book", Vector3(-4.0,0.25,-2.4)], ["ball", Vector3(3.0,0.25,1.8)]]:
  var prop = load("res://scenes/props/%s.tscn" % data[0]).instantiate()
  prop.position = data[1]
  add_child(prop)
 
 # Dynamic physics & breakable props
 var physics_props_data := [
  ["chair", Vector3(2.8,0.5,-0.8)],
  ["vase", Vector3(3.5,0.25,-2.6)],
  ["cup", Vector3(3.6,0.3,2.8)],
  ["bottle", Vector3(4.1,0.4,2.8)],
  ["slipper", Vector3(-4.5,0.2,1.1)],
  ["toy", Vector3(-3.4,0.2,2.2)],
  ["container", Vector3(0.9,0.25,2.8)],
  ["stack_box", Vector3(1.5,0.23,2.8)],
  ["stack_box", Vector3(1.5,0.68,2.8)],
  # Additional props for cleaning mission (sofa pillows & trash items)
  ["pillow", Vector3(-5.5,0.55,2.4)], # Pillow 2 on bed
  ["pillow", Vector3(-2.35,0.45,-1.75)], # Pillow 3 on coffee table
  ["bottle", Vector3(-5.2,0.85,-3.85)], # Trash bottle on desk
  ["cup", Vector3(3.9,0.3,2.8)], # Trash cup on kitchen counter
 ]
 for data in physics_props_data:
  var prop = preload("res://scripts/physics_prop.gd").new()
  prop.prop_kind = data[0]
  prop.position = data[1]
  add_child(prop)
 
 # Banana peel hazards
 for b_pos in [Vector3(-0.6, 0.05, 0.6), Vector3(-1.8, 0.05, 1.3)]:
  var banana = HazardBananaScript.new()
  banana.position = b_pos
  add_child(banana)
 
 # Placement Zones: Basket, Trash Bin, and 3 Sofa Pillow Slots
 var basket_zone = PlacementZoneScript.new()
 basket_zone.name = "BasketZone"
 basket_zone.zone_type = "basket"
 basket_zone.accepted_prop_kinds = ["toy", "bear", "book", "ball", "slipper", "container", "box"]
 basket_zone.capacity = 7
 basket_zone.position = Vector3(-0.7, 0.0, -1.2)
 add_child(basket_zone)
 
 var trash_zone = PlacementZoneScript.new()
 trash_zone.name = "TrashZone"
 trash_zone.zone_type = "trash"
 trash_zone.accepted_prop_kinds = ["bottle", "cup", "banana"]
 trash_zone.capacity = 8
 trash_zone.position = Vector3(2.2, 0.0, 1.8)
 add_child(trash_zone)
 
 var sofa_slots := []
 var sofa_slot_x := [-2.95, -2.35, -1.75]
 for i in 3:
  var slot = PlacementZoneScript.new()
  slot.name = "SofaSlot%d" % (i + 1)
  slot.zone_type = "sofa_slot"
  slot.accepted_prop_kinds = ["pillow"]
  slot.capacity = 1
  slot.snap_items = true
  slot.snap_rotation = Vector3(0.12, 0, 0)
  slot.position = Vector3(sofa_slot_x[i], 0.45, -0.42)
  add_child(slot)
  sofa_slots.append(slot)
 
 mission_manager.call("setup_zones", basket_zone, trash_zone, sofa_slots)
 
 main_camera = Camera3D.new()
 main_camera.set_script(load("res://scripts/shared_camera.gd"))
 main_camera.players = [p1]
 add_child(main_camera)
 
 var ui = GameUIScript.new()
 ui.name = "GameUI"
 ui.player = p1
 add_child(ui)
 var guidance = preload("res://scripts/workplace_guidance.gd").new()
 guidance.name = "WorkplaceGuidance"
 guidance.player = p1
 guidance.camera = main_camera
 add_child(guidance)
 var minimap = preload("res://scripts/ui/interactive_minimap.gd").new()
 minimap.name = "InteractiveMinimap"
 minimap.player = p1
 minimap.guidance = guidance
 add_child(minimap)
 ui.call("setup", round_manager, score_manager, challenge_manager)
 ui.call("setup_cleaning", mission_manager)

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

func enable_coop_mode() -> void:
 if is_coop: return
 is_coop = true
 p2 = preload("res://scenes/player.tscn").instantiate()
 p2.name = "Player2"
 p2.player_id = 2
 p2.position = Vector3(1.0, 0, 1.0)
 add_child(p2)
 p2.select_character("girl")
 
 if is_instance_valid(main_camera):
  main_camera.current = false
  main_camera.visible = false
 
 coop_manager = CoopManager.new()
 coop_manager.name = "CoopManager"
 add_child(coop_manager)
 coop_manager.initialize_coop(p1, p2, self, get_viewport().world_3d, true)

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_F11:
   var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
