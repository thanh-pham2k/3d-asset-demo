extends Node3D
# Maps the gameplay-neutral visual adapter interface to Kenney Mini Characters clips.
@export var model_scene: PackedScene
@export var model_scale := 1.9
@export var use_cream_shirt := false
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var hand_anchor: Marker3D
var current_state := "idle"
var was_holding := false
var pickup_until := 0.0
var hammer_until := 0.0

func _ready() -> void:
 if not model_scene: return
 model = model_scene.instantiate()
 model.scale = Vector3.ONE * model_scale
 # Kenney model faces +Z, matching gameplay forward.
 add_child(model)
 if use_cream_shirt: _apply_cream_shirt()
 animation = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
 skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
 if skeleton:
  var attachment := BoneAttachment3D.new()
  attachment.name = "RightHandBone"
  attachment.bone_name = "arm-right"
  skeleton.add_child(attachment)
  hand_anchor = Marker3D.new()
  hand_anchor.name = "HandAttachment"
  # The pack has one arm bone, so place the marker near the end of that arm.
  hand_anchor.position = Vector3(-0.16, -0.08, 0.0)
  attachment.add_child(hand_anchor)
 if animation:
  for clip in ["idle", "walk", "sprint", "holding-both", "sit", "fall"]:
   if animation.has_animation(clip): animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
  animation.play("idle")

func get_hand_anchor() -> Marker3D:
 return hand_anchor

func trigger_action(action: String, time: float) -> void:
 if action == "hammer": hammer_until = time + 0.35

func update_pose(move: float, running: bool, holding: bool, throwing: bool, resting: bool, lying: bool, reacting: bool, time: float, riding: bool = false) -> void:
 if not animation: return
 if holding and not was_holding: pickup_until = time + 0.28
 was_holding = holding
 var next := "idle"
 if riding:
  next = "sit"
 elif move > 0.05: next = "sprint" if running else "walk"
 if holding: next = "holding-both"
 if holding and time < pickup_until: next = "pick-up"
 if throwing or time < hammer_until: next = "attack-melee-right"
 if reacting: next = "die"
 if resting: next = "fall" if lying else "sit"
 if not animation.has_animation(next): next = "idle"
 if next != current_state or not animation.is_playing():
  animation.play(next, 0.12)
  current_state = next

func _apply_cream_shirt() -> void:
 # Only duplicate the body material and recolor the green shirt palette strip;
 # the source texture and the girl's materials remain untouched.
 var body := model.find_child("body-mesh", true, false) as MeshInstance3D
 if not body: return
 var source := body.get_active_material(0) as StandardMaterial3D
 if not source or not source.albedo_texture: return
 var bitmap := source.albedo_texture.get_image()
 if not bitmap or bitmap.get_width() != 512 or bitmap.get_height() != 512: return
 bitmap.convert(Image.FORMAT_RGBA8)
 for y in range(256,384):
  for x in range(96,128):
   var original := bitmap.get_pixel(x,y)
   var shade := lerpf(0.76,0.99, clampf((original.g-0.50)/0.29, 0.0, 1.0))
   bitmap.set_pixel(x,y,Color(shade,shade*0.97,shade*0.90,original.a))
 var material := source.duplicate() as StandardMaterial3D
 material.albedo_texture = ImageTexture.create_from_image(bitmap)
 body.set_surface_override_material(0, material)
