class_name NPCVisual
extends Node3D

## Cozy stylized low-poly Vietnamese NPC visual with articulated limbs,
## customizable colors, and authentic accessories (nón lá, apron, cap, etc.)

var skeleton: Skeleton3D
var body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D

var left_eye: MeshInstance3D
var right_eye: MeshInstance3D
var mouth: MeshInstance3D

var accessory_node: Node3D

var shirt_color: Color = Color("f4c451")
var pants_color: Color = Color("39465e")
var hair_color: Color = Color("594339")
var skin_color: Color = Color("f4c9ab")
var gender: String = "boy"
var accessory: String = "none"

func setup(data: NPCData) -> void:
	gender = data.gender
	shirt_color = data.shirt_color
	pants_color = data.pants_color
	hair_color = data.hair_color
	skin_color = data.skin_color
	accessory = data.accessory
	_build()

func _ready() -> void:
	if get_child_count() == 0:
		_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	
	skeleton = Skeleton3D.new()
	skeleton.name = "Rig"
	add_child(skeleton)
	
	_add_bone("root", -1, Vector3.ZERO)
	_add_bone("head", 0, Vector3(0, 1.28, 0))
	_add_bone("left_arm", 0, Vector3(-0.31, 0.87, 0))
	_add_bone("right_arm", 0, Vector3(0.31, 0.87, 0))
	_add_bone("left_leg", 0, Vector3(-0.13, 0.48, 0))
	_add_bone("right_leg", 0, Vector3(0.13, 0.48, 0))
	
	# Torso
	body = _attachment("Torso", "root")
	Art.box(body, Vector3(0, 0.70, 0), Vector3(0.46, 0.50, 0.28), shirt_color)
	
	# Head
	head = _attachment("HeadJoint", "head")
	Art.ball(head, Vector3.ZERO, 0.30, skin_color, Vector3(1, 0.95, 0.94))
	
	# Hair based on gender / style
	if gender == "boy":
		# Short neat hair
		Art.ball(head, Vector3(0, 0.16, -0.02), 0.31, hair_color, Vector3(1.0, 0.54, 0.98))
		for x in [-0.18, 0.0, 0.18]:
			Art.box(head, Vector3(x, 0.18, 0.16), Vector3(0.14, 0.14, 0.15), hair_color, Vector3(0, 0, x))
	else:
		# Feminine hair with ponytail or bun
		Art.ball(head, Vector3(0, 0.16, -0.02), 0.31, hair_color, Vector3(1.0, 0.58, 1.0))
		Art.box(head, Vector3(0, -0.02, -0.20), Vector3(0.52, 0.40, 0.15), hair_color)
		Art.ball(head, Vector3(0.0, 0.18, -0.25), 0.16, hair_color) # cute bun
		Art.box(head, Vector3(-0.20, 0.22, 0.01), Vector3(0.14, 0.10, 0.08), Color("ef8fa5"), Vector3(0, 0, 0.35))
	
	# Face features
	left_eye = Art.ball(head, Vector3(-0.11, 0.02, 0.27), 0.032, Color("362820"), Vector3(0.7, 1.2, 0.4))
	right_eye = Art.ball(head, Vector3(0.11, 0.02, 0.27), 0.032, Color("362820"), Vector3(0.7, 1.2, 0.4))
	mouth = Art.box(head, Vector3(0, -0.08, 0.28), Vector3(0.08, 0.02, 0.015), Color("9c5b58"))
	
	# Limbs
	left_arm = _limb("LeftArm", "left_arm", Vector3(0.14, 0.40, 0.15), shirt_color)
	right_arm = _limb("RightArm", "right_arm", Vector3(0.14, 0.40, 0.15), shirt_color)
	left_leg = _limb("LeftLeg", "left_leg", Vector3(0.18, 0.44, 0.20), pants_color)
	right_leg = _limb("RightLeg", "right_leg", Vector3(0.18, 0.44, 0.20), pants_color)
	
	# Hands & Shoes
	for arm in [left_arm, right_arm]:
		Art.ball(arm, Vector3(0, -0.40, 0), 0.075, skin_color)
	for leg in [left_leg, right_leg]:
		Art.box(leg, Vector3(0, -0.42, 0.05), Vector3(0.20, 0.09, 0.28), Color("eae5da"))
	
	# Accessories
	_add_accessory()

func _add_accessory() -> void:
	match accessory:
		"conical_hat":
			# Iconic Vietnamese Nón Lá on head
			var hat := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.02
			cone.bottom_radius = 0.46
			cone.height = 0.22
			cone.radial_segments = 16
			hat.mesh = cone
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("eedab3") # Straw bamboo color
			m.roughness = 0.95
			hat.material_override = m
			hat.position = Vector3(0, 0.32, 0)
			head.add_child(hat)
		
		"cap":
			# Baseball / mechanic cap
			var cap_mesh := MeshInstance3D.new()
			var cap_sphere := SphereMesh.new()
			cap_sphere.radius = 0.32
			cap_sphere.height = 0.35
			cap_mesh.mesh = cap_sphere
			cap_mesh.material_override = Art.material(Color("34495e"))
			cap_mesh.position = Vector3(0, 0.16, -0.02)
			head.add_child(cap_mesh)
			# Brim
			Art.box(head, Vector3(0, 0.15, 0.26), Vector3(0.32, 0.025, 0.22), Color("2c3e50"))
		
		"apron":
			# White / cream cooking or vendor apron
			Art.box(body, Vector3(0, 0.65, 0.145), Vector3(0.38, 0.44, 0.02), Color("faf8f2"))
			# Apron straps
			Art.box(body, Vector3(-0.14, 0.88, 0.08), Vector3(0.04, 0.18, 0.14), Color("e0ded5"))
			Art.box(body, Vector3(0.14, 0.88, 0.08), Vector3(0.04, 0.18, 0.14), Color("e0ded5"))
		
		"glasses":
			# Cute reading glasses on face
			var m := Art.material(Color("222222"))
			for x in [-0.11, 0.11]:
				var rim := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 0.045
				torus.outer_radius = 0.065
				rim.mesh = torus
				rim.material_override = m
				rim.rotation_degrees = Vector3(90, 0, 0)
				rim.position = Vector3(x, 0.02, 0.29)
				head.add_child(rim)
			Art.box(head, Vector3(0, 0.02, 0.29), Vector3(0.08, 0.015, 0.01), Color("222222"))
		
		"backpack":
			# Student backpack on back
			Art.box(body, Vector3(0, 0.68, -0.20), Vector3(0.34, 0.40, 0.16), Color("d9534f"))
		
		"headband":
			# Sport headband
			Art.box(head, Vector3(0, 0.14, 0.0), Vector3(0.62, 0.06, 0.62), Color("e74c3c"))

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

func _limb(node_name: String, bone_name: String, size: Vector3, color: Color) -> Node3D:
	var pivot := _attachment(node_name, bone_name)
	Art.box(pivot, Vector3(0, -size.y / 2.0, 0), size, color)
	return pivot

func _pose_joint(bone_name: String, euler: Vector3) -> void:
	if not is_instance_valid(skeleton):
		_build()
	if not is_instance_valid(skeleton): return
	var idx := skeleton.find_bone(bone_name)
	if idx >= 0:
		skeleton.set_bone_pose_rotation(idx, Quaternion.from_euler(euler))

func update_animation(walk_speed: float, time: float, is_talking: bool, activity: String = "idle", seated: bool = false) -> void:
	if not is_instance_valid(skeleton): return
	
	if seated:
		# Seat origin is at cushion height; move the rig down to put hips on it.
		skeleton.position.y = -0.48
		_pose_joint("left_leg", Vector3(-1.35, 0, 0))
		_pose_joint("right_leg", Vector3(-1.35, 0, 0))
		_pose_joint("left_arm", Vector3(-0.35, 0, 0.1))
		_pose_joint("right_arm", Vector3(-0.35, 0, -0.1))
		_pose_joint("head", Vector3(0, sin(time * 0.8) * 0.08, 0))
	elif walk_speed > 0.05:
		# Walking cycle
		var swing := sin(time * 8.5)
		_pose_joint("left_leg", Vector3(swing * 0.55, 0, 0))
		_pose_joint("right_leg", Vector3(-swing * 0.55, 0, 0))
		_pose_joint("left_arm", Vector3(-swing * 0.45, 0, 0))
		_pose_joint("right_arm", Vector3(swing * 0.45, 0, 0))
		_pose_joint("head", Vector3(0, 0, 0))
		skeleton.position.y = absf(sin(time * 17.0)) * 0.04
	else:
		# Idle / standing
		skeleton.position.y = sin(time * 2.0) * 0.015
		_pose_joint("left_leg", Vector3.ZERO)
		_pose_joint("right_leg", Vector3.ZERO)
		
		if is_talking:
			# Expressive arm gestures and head nods
			var talk_cycle := sin(time * 6.0)
			_pose_joint("left_arm", Vector3(-0.35 + talk_cycle * 0.12, 0, 0.15))
			_pose_joint("right_arm", Vector3(-0.45 - talk_cycle * 0.15, 0, -0.15))
			_pose_joint("head", Vector3(talk_cycle * 0.08, 0, 0))
		elif activity == "lunch":
			# A small eating gesture; seating is not implied without a chair anchor.
			_pose_joint("left_arm", Vector3(-0.45, 0, 0.12))
			_pose_joint("right_arm", Vector3(-0.65 + sin(time * 2.3) * 0.2, 0, -0.1))
			_pose_joint("head", Vector3(0.1, 0, 0))
		else:
			_pose_joint("left_arm", Vector3(0, 0, 0))
			_pose_joint("right_arm", Vector3(0, 0, 0))
			_pose_joint("head", Vector3(0, sin(time * 0.8) * 0.12, 0)) # gentle looking around
