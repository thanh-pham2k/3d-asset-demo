extends CharacterBody3D

var player_id := 1
var visual: Node3D
var hold_anchor: Node3D
var held_pillow: Node3D
var resting: Interactable
var facing := Vector3(0,0,1)
var impulse := Vector3.ZERO
var reaction := 0.0
var throw_anim := 0.0
var time := 0.0
var interaction_cooldown := 0.0
var dash_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_direction := Vector3.ZERO
var footstep_timer := 0.0
var hammer_cooldown := 0.0
var knockback_fx_timer := 0.0
var dizzy_fx_pending := false
var target: Node3D
var prompt_label: Label3D
@export var config: PlayerConfig = PlayerConfig.new()
var animation_controller: Node

func _ready() -> void:
 add_to_group("players")
 collision_layer = 2
 collision_mask = 7
 var col = CollisionShape3D.new()
 var capsule = CapsuleShape3D.new()
 capsule.radius = 0.23
 capsule.height = 1.15
 col.shape = capsule
 col.position.y = 0.58
 add_child(col)
 visual = Node3D.new()
 add_child(visual)
 visual.name = "VisualRoot"
 visual.position = config.visual_offset
 visual.scale = config.visual_scale
 var model_scene = config.visual_scene if config.visual_scene else preload("res://scenes/placeholder_visual.tscn")
 var model = model_scene.instantiate()
 if "player_id" in model: model.player_id = player_id
 visual.add_child(model)
 animation_controller = preload("res://scripts/animation_controller.gd").new()
 animation_controller.name = "AnimationController"
 animation_controller.model = model
 add_child(animation_controller)
 hold_anchor = Marker3D.new()
 hold_anchor.name = "HoldPoint"
 hold_anchor.position = config.hold_offset
 visual.add_child(hold_anchor)
 prompt_label = Label3D.new()
 prompt_label.position = Vector3(0,1.92,0)
 prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 prompt_label.font_size = 32
 prompt_label.pixel_size = 0.005
 prompt_label.outline_size = 8
 prompt_label.modulate = Color("fff7e8")
 add_child(prompt_label)

func select_character(variant: String) -> void:
 # Replacing a visual never replaces the physics body or gameplay components.
 if variant not in ["boy", "girl"]: return
 var kenney := OS.get_environment("COUPLE_VISUAL") == "kenney"
 var prefix := "kenney_" if kenney else ""
 var scene: PackedScene = load("res://scenes/characters/%s%s_visual.tscn" % [prefix, variant])
 var old_model = animation_controller.model
 visual.remove_child(old_model)
 old_model.queue_free()
 var replacement = scene.instantiate()
 visual.add_child(replacement)
 visual.move_child(replacement, 0)
 animation_controller.model = replacement
 animation_controller.first_update = true
 config.visual_scene = scene

func _physics_process(delta: float) -> void:
 time += delta
 interaction_cooldown = max(0.0, interaction_cooldown - delta)
 reaction = max(0.0, reaction - delta)
 if reaction > 0.0:
  knockback_fx_timer -= delta
  var reaction_fx = get_tree().get_first_node_in_group("chaos_feedback")
  if reaction_fx and knockback_fx_timer <= 0.0:
   reaction_fx.play_event("knockback_trail", global_position + Vector3.UP * 0.4)
   knockback_fx_timer = 0.12
  if reaction_fx and dizzy_fx_pending and reaction < 0.2:
   reaction_fx.play_event("dizzy", global_position + Vector3.UP * 1.5)
   dizzy_fx_pending = false
 throw_anim = max(0.0, throw_anim - delta)
 dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
 hammer_cooldown = maxf(0.0, hammer_cooldown - delta)
 var prefix = "p%d_" % player_id
 if resting:
  velocity = Vector3.ZERO
  if Input.is_action_just_pressed(prefix + "interact") and interaction_cooldown <= 0:
   resting.interact(self)
   interaction_cooldown = 0.25
  update_animation(0.0, false)
  prompt_label.text = ("E" if player_id == 1 else "Enter") + "  " + (resting.prompt(self) if resting else "")
  return
 var input := Input.get_vector(prefix+"left",prefix+"right",prefix+"up",prefix+"down")
 # Camera faces the back wall, so world axes align with the screen.
 var right := Vector3.RIGHT
 var down := Vector3.BACK
 var direction := (right * input.x + down * input.y).limit_length(1.0)
 var running := Input.is_action_pressed(prefix+"run")
 var speed := config.run_speed if running else config.walk_speed
 if Input.is_action_just_pressed(prefix + "dash") and dash_cooldown_remaining <= 0.0:
  dash_direction = direction.normalized() if direction.length() > 0.08 else facing
  dash_remaining = config.dash_duration
  dash_cooldown_remaining = config.dash_cooldown
  facing = dash_direction
 if dash_remaining > 0.0:
  dash_remaining = maxf(0.0, dash_remaining - delta)
  direction = dash_direction
  speed = config.dash_speed
 var desired := direction * speed
 if dash_remaining > 0.0:
  velocity.x = desired.x
  velocity.z = desired.z
 else:
  velocity.x = move_toward(velocity.x, desired.x + impulse.x, config.acceleration * delta)
  velocity.z = move_toward(velocity.z, desired.z + impulse.z, config.acceleration * delta)
 impulse = impulse.move_toward(Vector3.ZERO, 9.0 * delta)
 if not is_on_floor(): velocity.y -= 18.0 * delta
 else: velocity.y = -0.1
 if direction.length() > 0.08:
  facing = direction.normalized()
  visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x,facing.z), 1.0-exp(-12.0*delta))
 var pre_slide_velocity := velocity
 move_and_slide()
 for i in get_slide_collision_count():
  var contact := get_slide_collision(i)
  var obstacle = contact.get_collider()
  if obstacle is RigidBody3D and not obstacle.freeze:
   var push := -contact.get_normal()
   push.y = 0.0
   obstacle.apply_central_impulse(push.normalized() * minf(pre_slide_velocity.length(), 3.0) * 1.0)
 footstep_timer -= delta
 if direction.length() > 0.1 and is_on_floor() and footstep_timer <= 0.0:
  var fx = get_tree().get_first_node_in_group("chaos_feedback")
  if fx:
   fx.play_event("footstep", global_position)
   if running: fx.play_event("running_dust", global_position)
  footstep_timer = 0.26 if running else 0.4
 find_target()
 if Input.is_action_just_pressed(prefix + "interact") and interaction_cooldown <= 0:
  if held_pillow:
   held_pillow.drop_from(self)
   interaction_cooldown = 0.25
  elif target:
   target.interact(self)
   interaction_cooldown = 0.25
 if Input.is_action_just_pressed(prefix + "swing") and held_pillow and held_pillow.prop_kind == "hammer" and hammer_cooldown <= 0.0:
  hammer_cooldown = 0.6
  animation_controller.trigger_action("hammer", time)
  var fx = get_tree().get_first_node_in_group("chaos_feedback")
  if fx: fx.play_event("throw", global_position + facing * 0.8 + Vector3.UP * 0.5)
  for item in get_tree().get_nodes_in_group("interactables"):
   var delta_pos: Vector3 = item.global_position - global_position
   if item != held_pillow and delta_pos.length() < 1.25 and delta_pos.dot(facing) > 0.0 and item.has_method("receive_impact"):
    item.receive_impact(facing * 4.0)
    if fx: fx.play_event("bonk", item.global_position)
 if Input.is_action_just_pressed(prefix + "throw") and held_pillow:
  held_pillow.throw_from(self)
  throw_anim = 0.35
 update_animation(direction.length(), running)

func find_target() -> void:
 target = null
 var nearest := 1.1
 for item in get_tree().get_nodes_in_group("interactables"):
  if not item.available(self): continue
  var distance: float = global_position.distance_to(item.global_position)
  if distance < nearest:
   nearest = distance
   target = item
 var key = "E" if player_id == 1 else "Enter"
 if held_pillow: prompt_label.text = ("F" if player_id == 1 else "Right Ctrl") + (" ném · Q đập · E thả" if held_pillow.prop_kind == "hammer" else " ném · E thả")
 elif target: prompt_label.text = key + "  " + target.prompt(self)
 else: prompt_label.text = "P%d" % player_id

func update_animation(move: float, running: bool) -> void:
 animation_controller.apply_state(move, running, held_pillow != null, throw_anim > 0, resting != null, resting != null and resting.kind == "bed", reaction > 0, time)
 # Optional visual adapter: unrelated models retain the configured gameplay anchor.
 var model = animation_controller.model
 if config.use_visual_hand_anchor and model.has_method("get_hand_anchor"):
  var hand = model.get_hand_anchor()
  if is_instance_valid(hand): hold_anchor.global_position = hand.global_position + facing * 0.10
 else:
  hold_anchor.position = config.hold_offset

func enter_rest(item: Interactable, point: Vector3, lying: bool) -> void:
 resting = item
 global_position = point
 collision_layer = 0
 collision_mask = 0
 visual.rotation.x = -PI/2 if lying else 0.0
 visual.rotation.y = 0

func leave_rest(point: Vector3) -> bool:
 var shape = CapsuleShape3D.new()
 shape.radius = 0.23
 shape.height = 1.15
 var query = PhysicsShapeQueryParameters3D.new()
 query.shape = shape
 query.collision_mask = 7
 query.exclude = [get_rid()]
 for offset in [Vector3.ZERO, Vector3(0.5,0,0), Vector3(-0.5,0,0), Vector3(0,0,0.5), Vector3(0,0,-0.5)]:
  var candidate: Vector3 = point + offset
  query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3(0,0.60,0))
  if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
   global_position = candidate
   visual.rotation.x = 0
   collision_layer = 2
   collision_mask = 7
   resting = null
   return true
 return false

func hit(direction: Vector3) -> void:
 if resting: return
 var fx = get_tree().get_first_node_in_group("chaos_feedback")
 if fx:
  fx.play_event("hit", global_position + Vector3.UP)
  fx.play_event("hit_stars", global_position + Vector3.UP * 1.4)
 impulse = direction.normalized() * 4.2
 reaction = 0.5
 dizzy_fx_pending = true
 knockback_fx_timer = 0.0
 var puff = GPUParticles3D.new()
 var process = ParticleProcessMaterial.new()
 process.direction = Vector3(0,1,0)
 process.spread = 60
 process.initial_velocity_min = 0.7
 process.initial_velocity_max = 1.5
 process.gravity = Vector3(0,-3,0)
 puff.process_material = process
 var mesh = SphereMesh.new()
 mesh.radius = 0.035
 mesh.height = 0.07
 mesh.material = Art.material(Color("fff1a7"))
 puff.draw_pass_1 = mesh
 puff.amount = 10
 puff.lifetime = 0.5
 puff.one_shot = true
 puff.position.y = 1.0
 add_child(puff)
 puff.emitting = true
 get_tree().create_timer(1.0).timeout.connect(puff.queue_free)
