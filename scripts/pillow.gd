extends CharacterBody3D

enum State { IDLE, HELD, THROWN }
@export_enum("pillow", "hammer", "bear", "box", "book", "ball") var prop_kind := "pillow"
var state := State.IDLE
var holder: Node3D
var thrower: Node3D
var hit_once := false
var ignore_timer := 0.0
var pickup_timer := 0.0
var spin := 0.0
var trail_timer := 0.0
var visual: Node3D
var chain_level := 0
var display_name := "Gối"
var item_category := "cushion"
var interaction_type := "pickup"
var valid_destinations: Array = ["sofa"]

func _ready() -> void:
 add_to_group("interactables")
 collision_layer = 4
 collision_mask = 3
 match prop_kind:
  "pillow":
   display_name = "Gối"
   item_category = "cushion"
   valid_destinations = ["sofa"]
  "hammer":
   display_name = "Búa đồ chơi"
   item_category = "tool"
   valid_destinations = ["basket"]
  "bear":
   display_name = "Gấu bông"
   item_category = "toy"
   valid_destinations = ["basket"]
  "box":
   display_name = "Hộp đồ"
   item_category = "toy"
   valid_destinations = ["basket"]
  "book":
   display_name = "Sách"
   item_category = "toy"
   valid_destinations = ["basket"]
  "ball":
   display_name = "Quả bóng"
   item_category = "toy"
   valid_destinations = ["basket"]
 var col = CollisionShape3D.new()
 var shape: Shape3D
 if prop_kind == "ball":
  var sphere := SphereShape3D.new()
  sphere.radius = 0.19
  shape = sphere
 else:
  var box_shape := BoxShape3D.new()
  box_shape.size = {"pillow": Vector3(0.46,0.18,0.36), "hammer": Vector3(0.50,0.55,0.24), "bear": Vector3(0.34,0.38,0.27), "box": Vector3(0.34,0.32,0.34), "book": Vector3(0.36,0.25,0.25)}.get(prop_kind, Vector3(0.38,0.38,0.38))
  shape = box_shape
 col.shape = shape
 add_child(col)
 visual = Node3D.new()
 visual.name = "PropVisual"
 add_child(visual)
 match prop_kind:
  "pillow":
   add_kenney_prop("pillowBlue", Vector3(0.115,0.064256,-0.031695), 2.0, true)
  "hammer":
   Art.box(visual, Vector3(0,-0.04,0), Vector3(0.11,0.48,0.11), Color("a96e4b"))
   Art.box(visual, Vector3(0,0.17,0), Vector3(0.50,0.22,0.23), Color("e98fa0"))
   Art.box(visual, Vector3(0,0.17,0), Vector3(0.25,0.23,0.24), Color("f1c65e"))
  "bear":
   Art.kenney(visual, "bear", Vector3(0,-0.19,0), 0.38)
  "box":
   add_kenney_prop("cardboardBoxClosed", Vector3(0.10625,0.1405,-0.10625), 1.2, false)
  "book":
   Art.kenney(visual, "books", Vector3(0,-0.19,0), 0.25)
  "ball":
   Art.ball(visual, Vector3.ZERO, 0.19, Color("e5b85f"))

func add_kenney_prop(asset: String, center: Vector3, factor: float, flatten: bool) -> void:
 var pivot := Node3D.new()
 visual.add_child(pivot)
 if flatten: pivot.rotation.x = -PI / 2.0
 var model = load("res://assets/kenney_props/%s.glb" % asset).instantiate()
 model.scale = Vector3.ONE * factor
 model.position = -center * factor
 pivot.add_child(model)
 if asset == "pillowBlue":
  for mesh in model.find_children("*", "MeshInstance3D", true, false):
   mesh.material_override = Art.material(Color("efabb7"))

func available(_player: Node3D) -> bool:
 return state == State.IDLE and pickup_timer <= 0
func prompt(_player: Node3D) -> String:
 return "Nhặt " + display_name
func interact(player: Node3D) -> void:
 if not available(player) or player.held_pillow: return
 state = State.HELD
 holder = player
 player.held_pillow = self
 velocity = Vector3.ZERO
 collision_layer = 0
 collision_mask = 0
 add_collision_exception_with(player)
 emit_feedback("pickup")

func emit_feedback(event: String) -> void:
 var fx = get_tree().get_first_node_in_group("chaos_feedback")
 if fx: fx.play_event(event, global_position)

func throw_from(player: Node3D) -> void:
 if state != State.HELD or holder != player: return
 global_position = player.hold_anchor.global_position
 holder = null
 player.held_pillow = null
 thrower = player
 state = State.THROWN
 chain_level = 1
 emit_feedback("throw")
 hit_once = false
 ignore_timer = 0.28
 pickup_timer = 0.5
 collision_layer = 4
 collision_mask = 7
 velocity = player.facing * 5.2 + Vector3.UP * 2.5
 add_collision_exception_with(player)
 var camera = get_viewport().get_camera_3d()
 if camera and camera.has_method("add_trauma"): camera.add_trauma(0.12)
 get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(player): remove_collision_exception_with(player))

func drop_from(player: Node3D) -> void:
 if state != State.HELD or holder != player: return
 global_position = player.hold_anchor.global_position + player.facing * 0.35
 holder = null
 player.held_pillow = null
 thrower = player
 state = State.THROWN
 chain_level = 0
 pickup_timer = 0.5
 collision_layer = 4
 collision_mask = 7
 velocity = player.facing * 0.4
 add_collision_exception_with(player)
 get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(player): remove_collision_exception_with(player))
 emit_feedback("drop")

func _physics_process(delta: float) -> void:
 pickup_timer = max(0.0, pickup_timer-delta)
 ignore_timer = max(0.0, ignore_timer-delta)
 if state == State.HELD:
  if is_instance_valid(holder):
   global_position = holder.hold_anchor.global_position
   visual.global_rotation = Vector3(0, holder.visual.global_rotation.y, 0)
  return
 if state == State.THROWN:
  trail_timer -= delta
  if trail_timer <= 0.0:
   emit_feedback("throw_trail")
   trail_timer = 0.12
  velocity.y -= 10.0 * delta
  spin += delta * 10.0
  visual.rotation = Vector3(spin, spin*0.5, 0)
  var collision = move_and_collide(velocity * delta)
  if collision:
   var body = collision.get_collider()
   if body is RigidBody3D:
    var impulse_vec: Vector3 = velocity * (0.45 * body.mass)
    body.apply_central_impulse(impulse_vec)
    if body.has_method("receive_impact"):
     body.receive_impact(impulse_vec, self)
    var score_mgr = get_tree().get_first_node_in_group("score_manager")
    if score_mgr:
     score_mgr.register_prop_hit(body, velocity.length(), false, global_position)
    var cam = get_viewport().get_camera_3d()
    if cam and cam.has_method("add_trauma"): cam.add_trauma(0.2)
   if body.is_in_group("players") and body != thrower and not hit_once:

    hit_once = true
    emit_feedback("bonk" if prop_kind == "hammer" else "pillow_impact")
    body.hit(Vector3(velocity.x,0,velocity.z))
    velocity = Vector3(velocity.x*0.25,1.0,velocity.z*0.25)
   elif collision.get_normal().y > 0.5:
    emit_feedback("landing")
    state = State.IDLE
    velocity = Vector3.ZERO
    visual.rotation = Vector3.ZERO
    collision_layer = 4
   else:
    emit_feedback("collision")
    velocity = velocity.bounce(collision.get_normal()) * 0.45
 elif state == State.IDLE:
  velocity.y -= 10.0 * delta
  move_and_slide()
  if is_on_floor(): velocity = Vector3.ZERO
