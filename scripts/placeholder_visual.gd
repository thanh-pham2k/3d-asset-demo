extends Node3D
# Articulated, swappable prototype visual. The body and joints do not own physics.
# Set variant_override in a scene to keep that appearance regardless of player ID.
@export_enum("Use player ID", "Boy", "Girl") var variant_override := 0
var player_id := 1
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D
var body: Node3D
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D
var mouth: MeshInstance3D
var left_brow: MeshInstance3D
var right_brow: MeshInstance3D
var expression := "happy"
var skeleton: Skeleton3D
const SKIN = Color("f4c9ab")
const HAIR = Color("594339")

func _ready() -> void:
 var variant := variant_override if variant_override != 0 else player_id
 var shirt := Color("f8f5e9") if variant == 1 else Color("f4c451")
 var pants := Color("39465e")
 skeleton = Skeleton3D.new()
 skeleton.name = "Rig"
 add_child(skeleton)
 _add_bone("root", -1, Vector3.ZERO)
 _add_bone("head", 0, Vector3(0,1.28,0))
 _add_bone("left_arm", 0, Vector3(-0.31,0.87,0))
 _add_bone("right_arm", 0, Vector3(0.31,0.87,0))
 _add_bone("left_leg", 0, Vector3(-0.13,0.48,0))
 _add_bone("right_leg", 0, Vector3(0.13,0.48,0))
 body = _attachment("Torso", "root")
 Art.box(body, Vector3(0,0.70,0), Vector3(0.47,0.5,0.28), shirt)
 # A small chest motif helps the silhouette read from the game camera.
 Art.box(body, Vector3(0,0.75,0.146), Vector3(0.095,0.085,0.012), Color("e79191"))
 head = _attachment("HeadJoint", "head")
 Art.ball(head, Vector3.ZERO, 0.32, SKIN, Vector3(1,0.95,0.94))
 Art.ball(head, Vector3(0,0.17,-0.025), 0.325, HAIR, Vector3(1,0.53,0.98))
 if variant == 1:
  for x in [-0.20,0.0,0.20]: Art.box(head, Vector3(x,0.18,0.19), Vector3(0.16,0.17,0.17), HAIR, Vector3(0,0,x))
 else:
  Art.box(head, Vector3(0,-0.01,-0.21), Vector3(0.58,0.42,0.15), HAIR)
  Art.ball(head, Vector3(0.12,0.22,-0.20), 0.18, HAIR)
  Art.box(head, Vector3(-0.24,0.26,0.01), Vector3(0.16,0.12,0.09), Color("ef8fa5"), Vector3(0,0,0.35))
  Art.box(head, Vector3(-0.36,0.26,0.01), Vector3(0.16,0.12,0.09), Color("ef8fa5"), Vector3(0,0,-0.35))
 left_eye = Art.ball(head, Vector3(-0.12,0.03,0.288), 0.035, Color("47382f"), Vector3(0.7,1.2,0.4))
 right_eye = Art.ball(head, Vector3(0.12,0.03,0.288), 0.035, Color("47382f"), Vector3(0.7,1.2,0.4))
 mouth = Art.box(head, Vector3(0,-0.08,0.30), Vector3(0.09,0.022,0.015), Color("9c5b58"))
 left_brow = Art.box(head, Vector3(-0.12,0.105,0.286), Vector3(0.085,0.014,0.014), HAIR)
 right_brow = Art.box(head, Vector3(0.12,0.105,0.286), Vector3(0.085,0.014,0.014), HAIR)
 left_arm = limb("LeftArm", "left_arm", Vector3(0.15,0.42,0.16), shirt)
 right_arm = limb("RightArm", "right_arm", Vector3(0.15,0.42,0.16), shirt)
 left_leg = limb("LeftLeg", "left_leg", Vector3(0.20,0.46,0.22), pants)
 right_leg = limb("RightLeg", "right_leg", Vector3(0.20,0.46,0.22), pants)
 for arm in [left_arm, right_arm]:
  Art.ball(arm, Vector3(0,-0.42,0), 0.08, SKIN)
  var marker := Marker3D.new()
  marker.name = "HandAttachment"
  marker.position = Vector3(0,-0.42,0.04)
  arm.add_child(marker)
 for leg in [left_leg, right_leg]:
  Art.box(leg, Vector3(0,-0.43,0.055), Vector3(0.22,0.10,0.32), Color("f6eee3"))
 set_expression("happy")

func _add_bone(bone_name: String, parent_index: int, offset: Vector3) -> void:
 skeleton.add_bone(bone_name)
 var index := skeleton.find_bone(bone_name)
 skeleton.set_bone_parent(index, parent_index)
 skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))
 skeleton.set_bone_pose_position(index, offset)

func _attachment(node_name: String, bone_name: String) -> BoneAttachment3D:
 var attachment := BoneAttachment3D.new()
 attachment.name = node_name
 attachment.bone_name = bone_name
 skeleton.add_child(attachment)
 return attachment

func limb(node_name: String, bone_name: String, size: Vector3, color: Color) -> Node3D:
 var pivot := _attachment(node_name, bone_name)
 Art.box(pivot, Vector3(0,-size.y/2,0), size, color)
 return pivot

func pose_joint(bone_name: String, euler: Vector3) -> void:
 skeleton.set_bone_pose_rotation(skeleton.find_bone(bone_name), Quaternion.from_euler(euler))

# Visual adapter hook: gameplay may use this after _ready(), with its own fallback.
func get_hand_anchor() -> Marker3D:
 if not is_instance_valid(right_arm): return null
 return right_arm.get_node_or_null("HandAttachment") as Marker3D

func set_expression(value: String) -> void:
 if not is_instance_valid(left_eye): return
 expression = value
 left_eye.scale = Vector3(0.7,1.2,0.4)
 right_eye.scale = left_eye.scale
 left_brow.rotation.z = 0.0
 right_brow.rotation.z = 0.0
 mouth.scale = Vector3.ONE
 match value:
  "angry":
   left_brow.rotation.z = -0.32
   right_brow.rotation.z = 0.32
   mouth.scale = Vector3(0.8,0.8,1)
  "surprised":
   mouth.scale = Vector3(0.5,2.2,1)
  "dizzy":
   left_eye.scale = Vector3(1.0,0.35,0.4)
   right_eye.scale = left_eye.scale
   left_brow.rotation.z = 0.25
   right_brow.rotation.z = -0.25
   mouth.scale = Vector3(0.55,1.5,1)
  "hurt":
   left_eye.scale = Vector3(0.9,0.2,0.4)
   right_eye.scale = left_eye.scale
   left_brow.rotation.z = 0.25
   right_brow.rotation.z = -0.25
   mouth.scale = Vector3(0.8,1.6,1)
