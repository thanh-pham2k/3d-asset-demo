extends CharacterBody3D

enum State { IDLE, HELD, THROWN }
var state := State.IDLE
var holder: Node3D
var thrower: Node3D
var hit_once := false
var ignore_timer := 0.0
var pickup_timer := 0.0
var spin := 0.0

func _ready() -> void:
 add_to_group("interactables")
 collision_layer = 4
 collision_mask = 3
 var col = CollisionShape3D.new()
 var shape = SphereShape3D.new()
 shape.radius = 0.19
 col.shape = shape
 add_child(col)
 Art.box(self, Vector3.ZERO, Vector3(0.46,0.18,0.36), Color("f1afbd"))
 Art.box(self, Vector3(0,0.096,0), Vector3(0.37,0.014,0.27), Color("f8c9cc"))

func available(_player: Node3D) -> bool:
 return state == State.IDLE and pickup_timer <= 0
func prompt(_player: Node3D) -> String:
 return "Nhặt gối"
func interact(player: Node3D) -> void:
 if not available(player) or player.held_pillow: return
 state = State.HELD
 holder = player
 player.held_pillow = self
 velocity = Vector3.ZERO
 collision_layer = 0
 collision_mask = 0

func throw_from(player: Node3D) -> void:
 if state != State.HELD or holder != player: return
 global_position = player.hold_anchor.global_position
 holder = null
 player.held_pillow = null
 thrower = player
 state = State.THROWN
 hit_once = false
 ignore_timer = 0.28
 pickup_timer = 0.5
 collision_mask = 3
 velocity = player.facing * 5.0 + Vector3.UP * 2.5
 add_collision_exception_with(player)
 get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(player): remove_collision_exception_with(player))

func _physics_process(delta: float) -> void:
 pickup_timer = max(0.0, pickup_timer-delta)
 ignore_timer = max(0.0, ignore_timer-delta)
 if state == State.HELD:
  if is_instance_valid(holder):
   global_position = holder.hold_anchor.global_position
   rotation = Vector3(0, holder.visual.global_rotation.y, 0)
  return
 if state == State.THROWN:
  velocity.y -= 10.0 * delta
  spin += delta * 10.0
  rotation = Vector3(spin, spin*0.5, 0)
  var collision = move_and_collide(velocity * delta)
  if collision:
   var body = collision.get_collider()
   if body.is_in_group("players") and body != thrower and not hit_once:
    hit_once = true
    body.hit(Vector3(velocity.x,0,velocity.z))
    velocity = Vector3(velocity.x*0.25,1.0,velocity.z*0.25)
   elif collision.get_normal().y > 0.5:
    state = State.IDLE
    velocity = Vector3.ZERO
    rotation = Vector3.ZERO
    global_position.y = 0.20
   else:
    velocity = velocity.bounce(collision.get_normal()) * 0.45
 elif global_position.y > 0.20:
  velocity.y -= 10.0 * delta
  move_and_slide()
  if is_on_floor(): velocity = Vector3.ZERO
