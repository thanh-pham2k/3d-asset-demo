class_name CatVisual
extends Node3D

## Procedural low-poly stylized Orange Tabby Cat for Couple Chaos 3D.
## Features cute chibi proportions, articulated bone hierarchy, dark orange tabby stripes,
## cream belly and muzzle, expressive eyes, and a festive red collar with brass bell.

# Color Palette (Warm pastel cozy low-poly aesthetic)
const COAT_ORANGE := Color("f59e56")       # Soft warm orange
const STRIPE_GINGER := Color("bf531c")     # Dark ginger tabby stripes
const CREAM_WHITE := Color("fff2db")       # Cream belly, paws, and muzzle
const NOSE_PINK := Color("f48fb1")         # Cute pink button nose
const INNER_EAR_PINK := Color("f8bbd0")    # Pastel pink inner ear
const EYE_TEAL := Color("26a69a")          # Expressive emerald-teal eyes
const PUPIL_DARK := Color("1a2327")        # Cat pupil
const COLLAR_RED := Color("d32f2f")        # Woven red collar
const BELL_GOLD := Color("ffd700")         # Shiny brass bell

# Articulated Joint References
var root_joint: Node3D
var body_joint: Node3D
var head_joint: Node3D
var ear_left: Node3D
var ear_right: Node3D
var muzzle_node: Node3D
var eye_left: Node3D
var eye_right: Node3D
var eye_left_mesh: MeshInstance3D
var eye_right_mesh: MeshInstance3D
var pupil_left: MeshInstance3D
var pupil_right: MeshInstance3D
var eye_left_happy: MeshInstance3D
var eye_right_happy: MeshInstance3D
var collar_node: Node3D
var bell_node: MeshInstance3D

var leg_fl: Node3D
var leg_fr: Node3D
var leg_bl: Node3D
var leg_br: Node3D

var tail_base: Node3D
var tail_mid: Node3D
var tail_tip: Node3D

var mouth_anchor: Marker3D
var head_anchor: Marker3D

var current_expression: String = "happy"

func _init() -> void:
	name = "CatVisual"

func _ready() -> void:
	_build_cat_model()
	set_expression("happy")

# -----------------------------------------------------------------
# Model Construction
# -----------------------------------------------------------------
func _build_cat_model() -> void:
	# Clear any previous children
	for child in get_children():
		child.queue_free()

	# Root Joint (Pivots at ground center)
	root_joint = Node3D.new()
	root_joint.name = "Root"
	add_child(root_joint)

	# Body Joint (Pivots at center of torso: Y=0.14)
	body_joint = Node3D.new()
	body_joint.name = "Body"
	body_joint.position = Vector3(0, 0.14, 0)
	root_joint.add_child(body_joint)

	# 1. Torso Geometry
	var torso_mesh := _create_sphere_mesh(Vector3(0.20, 0.16, 0.30), COAT_ORANGE)
	torso_mesh.name = "TorsoMesh"
	torso_mesh.position = Vector3(0, 0, 0)
	body_joint.add_child(torso_mesh)

	# Cream Belly Patch
	var belly_mesh := _create_sphere_mesh(Vector3(0.18, 0.11, 0.26), CREAM_WHITE)
	belly_mesh.name = "BellyMesh"
	belly_mesh.position = Vector3(0, -0.04, 0.02)
	body_joint.add_child(belly_mesh)

	# Cream Chest Fluff
	var chest_fluff := _create_sphere_mesh(Vector3(0.13, 0.10, 0.10), CREAM_WHITE)
	chest_fluff.name = "ChestFluff"
	chest_fluff.position = Vector3(0, 0.02, 0.12)
	body_joint.add_child(chest_fluff)

	# Tabby Stripes across back & flanks
	for z_offset in [-0.07, 0.0, 0.07]:
		var stripe := _create_box_mesh(Vector3(0.205, 0.05, 0.024), STRIPE_GINGER)
		stripe.position = Vector3(0, 0.065, z_offset)
		stripe.rotation.x = -0.08
		body_joint.add_child(stripe)

	# 2. Head Joint (Pivots at front-top of torso: Y=0.08, Z=0.15)
	head_joint = Node3D.new()
	head_joint.name = "Head"
	head_joint.position = Vector3(0, 0.08, 0.15)
	body_joint.add_child(head_joint)

	# Head Mesh (Large cute chibi head, slightly wide cheeks)
	var head_mesh := _create_sphere_mesh(Vector3(0.22, 0.19, 0.20), COAT_ORANGE)
	head_mesh.name = "HeadMesh"
	head_mesh.position = Vector3(0, 0.07, 0.04)
	head_joint.add_child(head_mesh)

	# Tabby "M" Forehead marking
	var m_stripe1 := _create_box_mesh(Vector3(0.018, 0.05, 0.015), STRIPE_GINGER)
	m_stripe1.position = Vector3(-0.03, 0.15, 0.12)
	head_joint.add_child(m_stripe1)

	var m_stripe2 := _create_box_mesh(Vector3(0.018, 0.05, 0.015), STRIPE_GINGER)
	m_stripe2.position = Vector3(0.03, 0.15, 0.12)
	head_joint.add_child(m_stripe2)

	var m_stripe_center := _create_box_mesh(Vector3(0.016, 0.04, 0.015), STRIPE_GINGER)
	m_stripe_center.position = Vector3(0.0, 0.16, 0.125)
	head_joint.add_child(m_stripe_center)

	# Cream Cheeks / Muzzle pads
	muzzle_node = Node3D.new()
	muzzle_node.name = "Muzzle"
	muzzle_node.position = Vector3(0, 0.04, 0.12)
	head_joint.add_child(muzzle_node)

	var cheek_l := _create_sphere_mesh(Vector3(0.065, 0.05, 0.05), CREAM_WHITE)
	cheek_l.position = Vector3(-0.035, 0, 0)
	muzzle_node.add_child(cheek_l)

	var cheek_r := _create_sphere_mesh(Vector3(0.065, 0.05, 0.05), CREAM_WHITE)
	cheek_r.position = Vector3(0.035, 0, 0)
	muzzle_node.add_child(cheek_r)

	var chin := _create_sphere_mesh(Vector3(0.055, 0.04, 0.04), CREAM_WHITE)
	chin.position = Vector3(0, -0.025, -0.01)
	muzzle_node.add_child(chin)

	# Pink Button Nose
	var nose := _create_sphere_mesh(Vector3(0.026, 0.02, 0.02), NOSE_PINK)
	nose.name = "Nose"
	nose.position = Vector3(0, 0.016, 0.024)
	muzzle_node.add_child(nose)

	# Mouth Anchor (for carrying toys/kibble)
	mouth_anchor = Marker3D.new()
	mouth_anchor.name = "MouthAnchor"
	mouth_anchor.position = Vector3(0, -0.01, 0.04)
	muzzle_node.add_child(mouth_anchor)

	# Head Top Anchor (for floating emotes, hearts, zzz)
	head_anchor = Marker3D.new()
	head_anchor.name = "HeadAnchor"
	head_anchor.position = Vector3(0, 0.22, 0.04)
	head_joint.add_child(head_anchor)

	# Ears
	ear_left = _create_cat_ear(true)
	ear_left.position = Vector3(-0.065, 0.15, 0.02)
	ear_left.rotation = Vector3(-0.1, -0.15, -0.25)
	head_joint.add_child(ear_left)

	ear_right = _create_cat_ear(false)
	ear_right.position = Vector3(0.065, 0.15, 0.02)
	ear_right.rotation = Vector3(-0.1, 0.15, 0.25)
	head_joint.add_child(ear_right)

	# Eyes
	eye_left = Node3D.new()
	eye_left.name = "EyeLeft"
	eye_left.position = Vector3(-0.058, 0.075, 0.118)
	head_joint.add_child(eye_left)

	eye_left_mesh = _create_sphere_mesh(Vector3(0.038, 0.045, 0.02), EYE_TEAL)
	eye_left.add_child(eye_left_mesh)

	pupil_left = _create_sphere_mesh(Vector3(0.018, 0.036, 0.01), PUPIL_DARK)
	pupil_left.position = Vector3(0, 0, 0.011)
	eye_left.add_child(pupil_left)

	# Specular catchlight
	var highlight_l := _create_sphere_mesh(Vector3(0.01, 0.01, 0.005), Color.WHITE)
	highlight_l.position = Vector3(0.008, 0.01, 0.014)
	eye_left.add_child(highlight_l)

	# Happy curved eye mesh (for happy/purr expression)
	eye_left_happy = _create_box_mesh(Vector3(0.036, 0.012, 0.01), PUPIL_DARK)
	eye_left_happy.rotation.z = 0.2
	eye_left_happy.visible = false
	eye_left.add_child(eye_left_happy)

	eye_right = Node3D.new()
	eye_right.name = "EyeRight"
	eye_right.position = Vector3(0.058, 0.075, 0.118)
	head_joint.add_child(eye_right)

	eye_right_mesh = _create_sphere_mesh(Vector3(0.038, 0.045, 0.02), EYE_TEAL)
	eye_right.add_child(eye_right_mesh)

	pupil_right = _create_sphere_mesh(Vector3(0.018, 0.036, 0.01), PUPIL_DARK)
	pupil_right.position = Vector3(0, 0, 0.011)
	eye_right.add_child(pupil_right)

	var highlight_r := _create_sphere_mesh(Vector3(0.01, 0.01, 0.005), Color.WHITE)
	highlight_r.position = Vector3(0.008, 0.01, 0.014)
	eye_right.add_child(highlight_r)

	eye_right_happy = _create_box_mesh(Vector3(0.036, 0.012, 0.01), PUPIL_DARK)
	eye_right_happy.rotation.z = -0.2
	eye_right_happy.visible = false
	eye_right.add_child(eye_right_happy)

	# Collar with Bell
	collar_node = Node3D.new()
	collar_node.name = "Collar"
	collar_node.position = Vector3(0, 0.01, 0.10)
	head_joint.add_child(collar_node)

	var collar_ring := _create_torus_mesh(0.08, 0.012, COLLAR_RED)
	collar_ring.rotation.x = PI / 2.0
	collar_node.add_child(collar_ring)

	bell_node = _create_sphere_mesh(Vector3(0.025, 0.025, 0.025), BELL_GOLD)
	bell_node.name = "Bell"
	bell_node.position = Vector3(0, -0.065, 0.045)
	collar_node.add_child(bell_node)

	# 3. Four Cute Stubby Legs
	# Front Left Leg
	leg_fl = _create_leg(true, true)
	leg_fl.name = "LegFL"
	leg_fl.position = Vector3(-0.075, -0.03, 0.09)
	body_joint.add_child(leg_fl)

	# Front Right Leg
	leg_fr = _create_leg(true, false)
	leg_fr.name = "LegFR"
	leg_fr.position = Vector3(0.075, -0.03, 0.09)
	body_joint.add_child(leg_fr)

	# Back Left Leg
	leg_bl = _create_leg(false, true)
	leg_bl.name = "LegBL"
	leg_bl.position = Vector3(-0.085, -0.02, -0.08)
	body_joint.add_child(leg_bl)

	# Back Right Leg
	leg_br = _create_leg(false, false)
	leg_br.name = "LegBR"
	leg_br.position = Vector3(0.085, -0.02, -0.08)
	body_joint.add_child(leg_br)

	# 4. Tail (3 Articulated Segments with natural J-curve)
	tail_base = Node3D.new()
	tail_base.name = "TailBase"
	tail_base.position = Vector3(0, 0.04, -0.14)
	tail_base.rotation.x = 0.5
	body_joint.add_child(tail_base)

	var t1_mesh := _create_cylinder_mesh(0.024, 0.022, 0.07, COAT_ORANGE)
	t1_mesh.position = Vector3(0, 0.035, 0)
	tail_base.add_child(t1_mesh)

	var t1_stripe := _create_cylinder_mesh(0.0245, 0.0235, 0.018, STRIPE_GINGER)
	t1_stripe.position = Vector3(0, 0.035, 0)
	tail_base.add_child(t1_stripe)

	tail_mid = Node3D.new()
	tail_mid.name = "TailMid"
	tail_mid.position = Vector3(0, 0.065, 0)
	tail_mid.rotation.x = 0.4
	tail_base.add_child(tail_mid)

	var t2_mesh := _create_cylinder_mesh(0.022, 0.018, 0.07, COAT_ORANGE)
	t2_mesh.position = Vector3(0, 0.035, 0)
	tail_mid.add_child(t2_mesh)

	var t2_stripe := _create_cylinder_mesh(0.0225, 0.0195, 0.018, STRIPE_GINGER)
	t2_stripe.position = Vector3(0, 0.035, 0)
	tail_mid.add_child(t2_stripe)

	tail_tip = Node3D.new()
	tail_tip.name = "TailTip"
	tail_tip.position = Vector3(0, 0.065, 0)
	tail_tip.rotation.x = 0.5
	tail_mid.add_child(tail_tip)

	# Tail tip is white/cream
	var t3_mesh := _create_cylinder_mesh(0.018, 0.012, 0.06, CREAM_WHITE)
	t3_mesh.position = Vector3(0, 0.03, 0)
	tail_tip.add_child(t3_mesh)

	var t3_ball := _create_sphere_mesh(Vector3(0.014, 0.014, 0.014), CREAM_WHITE)
	t3_ball.position = Vector3(0, 0.06, 0)
	tail_tip.add_child(t3_ball)

# -----------------------------------------------------------------
# Helper Mesh Builders
# -----------------------------------------------------------------
func _create_cat_ear(_is_left: bool) -> Node3D:
	var ear := Node3D.new()
	ear.name = "EarLeft" if _is_left else "EarRight"

	# Outer Ear (low-poly triangular prism)
	var outer := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.065, 0.07, 0.03)
	outer.mesh = prism
	outer.material_override = _get_matte_material(COAT_ORANGE)
	outer.position = Vector3(0, 0.035, 0)
	ear.add_child(outer)

	# Inner Ear (pink inset)
	var inner := MeshInstance3D.new()
	var in_prism := PrismMesh.new()
	in_prism.size = Vector3(0.045, 0.05, 0.015)
	inner.mesh = in_prism
	inner.material_override = _get_matte_material(INNER_EAR_PINK)
	inner.position = Vector3(0, 0.032, 0.01)
	ear.add_child(inner)

	return ear

func _create_leg(is_front: bool, _is_left: bool) -> Node3D:
	var leg := Node3D.new()

	if not is_front:
		# Thicker cat thigh for hind legs
		var thigh := _create_sphere_mesh(Vector3(0.065, 0.09, 0.075), COAT_ORANGE)
		thigh.position = Vector3(0, -0.01, 0)
		leg.add_child(thigh)

	# Main Leg Shaft
	var shaft := _create_cylinder_mesh(0.028, 0.024, 0.09 if is_front else 0.08, COAT_ORANGE)
	shaft.position = Vector3(0, -0.045, 0)
	leg.add_child(shaft)

	# White/Cream Sock Paw
	var paw := _create_sphere_mesh(Vector3(0.045, 0.03, 0.055), CREAM_WHITE)
	paw.position = Vector3(0, -0.09, 0.015)
	leg.add_child(paw)

	# Pink Toe Beans underneath
	var pad_center := _create_box_mesh(Vector3(0.02, 0.005, 0.02), NOSE_PINK)
	pad_center.position = Vector3(0, -0.104, 0.012)
	leg.add_child(pad_center)

	return leg

func _create_sphere_mesh(size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 14
	s.rings = 8
	m.mesh = s
	m.scale = size
	m.material_override = _get_matte_material(col)
	return m

func _create_box_mesh(size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = _get_matte_material(col)
	return m

func _create_cylinder_mesh(top_r: float, bot_r: float, h: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bot_r
	c.height = h
	c.radial_segments = 12
	c.rings = 2
	m.mesh = c
	m.material_override = _get_matte_material(col)
	return m

func _create_torus_mesh(outer_r: float, inner_r: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = outer_r - inner_r
	t.outer_radius = outer_r
	t.ring_segments = 12
	t.rings = 12
	m.mesh = t
	m.material_override = _get_matte_material(col)
	return m

func _get_matte_material(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.88 # Soft warm matte appearance
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return mat

# -----------------------------------------------------------------
# Facial Expressions & Customization
# -----------------------------------------------------------------
func set_expression(expr: String) -> void:
	current_expression = expr
	if not is_instance_valid(eye_left_mesh): return

	match expr:
		"happy", "purr", "sleep":
			eye_left_mesh.visible = false
			pupil_left.visible = false
			eye_right_mesh.visible = false
			pupil_right.visible = false
			eye_left_happy.visible = true
			eye_right_happy.visible = true
		"wink":
			eye_left_mesh.visible = true
			pupil_left.visible = true
			eye_right_mesh.visible = false
			pupil_right.visible = false
			eye_left_happy.visible = false
			eye_right_happy.visible = true
		_: # "alert", "curious", "play", "idle"
			eye_left_mesh.visible = true
			pupil_left.visible = true
			eye_right_mesh.visible = true
			pupil_right.visible = true
			eye_left_happy.visible = false
			eye_right_happy.visible = false

func set_collar_visible(is_vis: bool) -> void:
	if is_instance_valid(collar_node):
		collar_node.visible = is_vis

func get_mouth_anchor() -> Marker3D:
	return mouth_anchor

func get_head_anchor() -> Marker3D:
	return head_anchor
