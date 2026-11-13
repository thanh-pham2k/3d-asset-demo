class_name PetAnimationController
extends Node

## Animation Controller & Adapter for stylized pets.
## Drives procedural joint articulation and builds standard Godot AnimationPlayer
## libraries with all 10 required animations:
## (idle, walk, run, sit, sleep, eat, drink, play, happy, follow_turn).

signal animation_started(anim_name: String)
signal animation_finished(anim_name: String)

@export var cat_visual: CatVisual
@export var animation_player: AnimationPlayer

var current_state: String = "idle"
var state_time: float = 0.0
var blend_weight: float = 1.0

# Procedural parameters
var turn_angle: float = 0.0
var move_speed: float = 0.0
var is_excited: bool = false

func _ready() -> void:
	if not cat_visual:
		cat_visual = get_parent().get_node_or_null("CatVisual") as CatVisual
		if not cat_visual and get_parent() is CatVisual:
			cat_visual = get_parent() as CatVisual
			
	if not animation_player:
		animation_player = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer
		if not animation_player:
			animation_player = AnimationPlayer.new()
			animation_player.name = "AnimationPlayer"
			add_child(animation_player)
			
	_ensure_animation_library()
	set_state("idle")

func _process(delta: float) -> void:
	state_time += delta
	_update_procedural_pose(delta)

# -----------------------------------------------------------------
# State & Animation Triggers
# -----------------------------------------------------------------
func set_state(new_state: String) -> void:
	if current_state == new_state: return
	current_state = new_state
	state_time = 0.0
	
	if is_instance_valid(cat_visual):
		match current_state:
			"sleep":
				cat_visual.set_expression("sleep")
			"happy":
				cat_visual.set_expression("happy")
			"play":
				cat_visual.set_expression("alert")
			"eat", "drink":
				cat_visual.set_expression("happy")
			_:
				cat_visual.set_expression("alert" if is_excited else "happy")
				
	if is_instance_valid(animation_player) and animation_player.has_animation(new_state):
		animation_player.play(new_state)
		
	animation_started.emit(current_state)

func play_action(action_name: String) -> void:
	set_state(action_name)

# -----------------------------------------------------------------
# Procedural Pose Updater (Fallback & Real-time Blend)
# -----------------------------------------------------------------
func _update_procedural_pose(delta: float) -> void:
	if not is_instance_valid(cat_visual) or not cat_visual.body_joint: return
	
	var t := state_time
	var body := cat_visual.body_joint
	var head := cat_visual.head_joint
	var l_fl := cat_visual.leg_fl
	var l_fr := cat_visual.leg_fr
	var l_bl := cat_visual.leg_bl
	var l_br := cat_visual.leg_br
	var t_base := cat_visual.tail_base
	var t_mid := cat_visual.tail_mid
	var t_tip := cat_visual.tail_tip

	match current_state:
		"idle":
			# Gentle breathing & subtle tail swishing
			var breath := sin(t * 2.8) * 0.008
			body.position.y = 0.14 + breath
			body.rotation = Vector3(0, 0, 0)
			head.position = Vector3(0, 0.08, 0.15)
			head.rotation = Vector3(sin(t * 1.4) * 0.04, cos(t * 0.7) * 0.08, 0)
			
			# Neutral standing paws
			l_fl.rotation = Vector3.ZERO
			l_fr.rotation = Vector3.ZERO
			l_bl.rotation = Vector3.ZERO
			l_br.rotation = Vector3.ZERO
			
			# Rhythmic tail swish
			t_base.rotation = Vector3(0.5, sin(t * 2.0) * 0.18, 0)
			t_mid.rotation = Vector3(0.4, sin(t * 2.0 + 0.4) * 0.22, 0)
			t_tip.rotation = Vector3(0.5, sin(t * 2.0 + 0.8) * 0.28, 0)

		"walk":
			# 4-beat diagonal trot gait
			var step := t * 9.0
			var bounce: float = abs(sin(step)) * 0.015
			body.position.y = 0.14 + bounce
			body.rotation = Vector3(sin(step) * 0.03, sin(step * 0.5) * 0.05, cos(step) * 0.04)
			
			head.position = Vector3(0, 0.08, 0.15)
			head.rotation = Vector3(-sin(step) * 0.05, 0, 0)
			
			# Diagonal leg pair timing
			l_fl.rotation.x = sin(step) * 0.52
			l_fr.rotation.x = -sin(step) * 0.52
			l_bl.rotation.x = -sin(step) * 0.45
			l_br.rotation.x = sin(step) * 0.45
			
			# Tail up and gently counter-swaying
			t_base.rotation = Vector3(0.6, -sin(step * 0.5) * 0.22, 0)
			t_mid.rotation = Vector3(0.5, -sin(step * 0.5 + 0.3) * 0.25, 0)
			t_tip.rotation = Vector3(0.4, -sin(step * 0.5 + 0.6) * 0.30, 0)

		"run":
			# Bounding gallop gait
			var step := t * 15.0
			var vertical: float = abs(sin(step)) * 0.03
			body.position.y = 0.14 + vertical
			body.rotation = Vector3(sin(step) * 0.14, 0, 0)
			
			head.position = Vector3(0, 0.07, 0.16)
			head.rotation = Vector3(0.08, 0, 0)
			
			# Paws synchronized bounding
			l_fl.rotation.x = sin(step) * 0.85
			l_fr.rotation.x = sin(step + 0.3) * 0.82
			l_bl.rotation.x = -sin(step) * 0.80
			l_br.rotation.x = -sin(step + 0.3) * 0.78
			
			# Tail streaming behind
			t_base.rotation = Vector3(0.2, sin(step) * 0.12, 0)
			t_mid.rotation = Vector3(0.1, sin(step + 0.3) * 0.15, 0)
			t_tip.rotation = Vector3(0.15, sin(step + 0.6) * 0.18, 0)

		"sit":
			# Hind legs folded flat, torso tilted up, front paws straight
			body.position.y = 0.08
			body.rotation = Vector3(0.38, 0, 0)
			
			head.position = Vector3(0, 0.09, 0.14)
			head.rotation = Vector3(-0.35 + sin(t * 1.5) * 0.03, cos(t * 0.8) * 0.06, 0)
			
			l_fl.rotation = Vector3(-0.38, 0, 0)
			l_fr.rotation = Vector3(-0.38, 0, 0)
			l_bl.rotation = Vector3(1.35, 0.2, 0)
			l_br.rotation = Vector3(1.35, -0.2, 0)
			
			# Tail curled neatly around paws
			t_base.rotation = Vector3(-0.35, 1.15, 0)
			t_mid.rotation = Vector3(0.1, 0.85, 0)
			t_tip.rotation = Vector3(0.2, 0.65, sin(t * 2.0) * 0.15)

		"sleep":
			# Loaf / Croissant sleeping pose
			var deep_breath := sin(t * 1.8) * 0.007
			body.position.y = 0.05 + deep_breath
			body.rotation = Vector3(0.05, 0.15, 0.08)
			
			head.position = Vector3(0.04, 0.02, 0.14)
			head.rotation = Vector3(0.25, 0.65, 0.35)
			
			l_fl.rotation = Vector3(1.1, -0.3, 0)
			l_fr.rotation = Vector3(1.1, 0.3, 0)
			l_bl.rotation = Vector3(1.4, 0.3, 0)
			l_br.rotation = Vector3(1.4, -0.3, 0)
			
			# Tail tucked snugly against side
			t_base.rotation = Vector3(-0.1, 1.6, 0)
			t_mid.rotation = Vector3(0.0, 1.3, 0)
			t_tip.rotation = Vector3(0.1, 0.8, 0)

		"eat":
			# Head dipped down into food bowl, rhythmic chewing
			body.position.y = 0.11
			body.rotation = Vector3(0.12, 0, 0)
			
			var chew := sin(t * 11.0) * 0.04
			head.position = Vector3(0, -0.04 + chew * 0.5, 0.18)
			head.rotation = Vector3(0.65 + chew, 0, 0)
			
			l_fl.rotation = Vector3(-0.12, 0, 0)
			l_fr.rotation = Vector3(-0.12, 0, 0)
			l_bl.rotation = Vector3(0.1, 0, 0)
			l_br.rotation = Vector3(0.1, 0, 0)
			
			# Content happy tail swishing
			t_base.rotation = Vector3(0.5, sin(t * 4.0) * 0.25, 0)
			t_mid.rotation = Vector3(0.4, sin(t * 4.0 + 0.4) * 0.3, 0)
			t_tip.rotation = Vector3(0.3, sin(t * 4.0 + 0.8) * 0.35, 0)

		"drink":
			# Head lowered toward water, quick gentle lapping
			body.position.y = 0.11
			body.rotation = Vector3(0.10, 0, 0)
			
			var lap := sin(t * 16.0) * 0.02
			head.position = Vector3(0, -0.05 + lap, 0.17)
			head.rotation = Vector3(0.58 + lap, 0, 0)
			
			l_fl.rotation = Vector3(-0.10, 0, 0)
			l_fr.rotation = Vector3(-0.10, 0, 0)
			l_bl.rotation = Vector3(0.1, 0, 0)
			l_br.rotation = Vector3(0.1, 0, 0)
			
			t_base.rotation = Vector3(0.4, sin(t * 2.0) * 0.12, 0)
			t_mid.rotation = Vector3(0.3, sin(t * 2.0 + 0.3) * 0.15, 0)
			t_tip.rotation = Vector3(0.3, sin(t * 2.0 + 0.6) * 0.2, 0)

		"play":
			# Playful crouch & paw batting
			var wiggle := sin(t * 12.0) * 0.09
			body.position.y = 0.09
			body.rotation = Vector3(0.2, 0, wiggle)
			
			head.position = Vector3(0, 0.07, 0.16)
			head.rotation = Vector3(-0.1, sin(t * 6.0) * 0.15, 0)
			
			# Alternating batting paws!
			var bat := sin(t * 9.0)
			l_fl.rotation.x = -0.6 + (bat if bat > 0 else 0.0) * 1.1
			l_fr.rotation.x = -0.6 + (-bat if bat < 0 else 0.0) * 1.1
			l_bl.rotation.x = 0.4 + wiggle * 0.5
			l_br.rotation.x = 0.4 - wiggle * 0.5
			
			# Excited tail flick
			t_base.rotation = Vector3(0.8, sin(t * 12.0) * 0.45, 0)
			t_mid.rotation = Vector3(0.7, sin(t * 12.0 + 0.3) * 0.5, 0)
			t_tip.rotation = Vector3(0.6, sin(t * 12.0 + 0.6) * 0.6, 0)

		"happy":
			# Standing head bunting upward & happy tail hook
			var purr_vibe := sin(t * 32.0) * 0.003
			body.position.y = 0.14 + purr_vibe
			body.rotation = Vector3(0, 0, purr_vibe * 2.0)
			
			# Chin stretched up asking for chin scratches
			head.position = Vector3(0, 0.11, 0.14)
			head.rotation = Vector3(-0.42 + sin(t * 3.0) * 0.06, sin(t * 1.5) * 0.08, 0)
			
			l_fl.rotation = Vector3.ZERO
			l_fr.rotation = Vector3.ZERO
			l_bl.rotation = Vector3.ZERO
			l_br.rotation = Vector3.ZERO
			
			# Classic happy cat vertical tail with J-hook at tip!
			t_base.rotation = Vector3(-1.25, sin(t * 4.0) * 0.08, 0)
			t_mid.rotation = Vector3(-0.35, sin(t * 4.0 + 0.3) * 0.10, 0)
			t_tip.rotation = Vector3(0.45, sin(t * 4.0 + 0.6) * 0.15, 0)

		"follow_turn", "turn":
			# Banked turning trot
			var step := t * 8.0
			body.position.y = 0.14 + abs(sin(step)) * 0.012
			body.rotation = Vector3(0, turn_angle * 0.3, -turn_angle * 0.15)
			
			head.position = Vector3(0, 0.08, 0.15)
			head.rotation = Vector3(0, turn_angle * 0.6, 0)
			
			l_fl.rotation.x = sin(step) * 0.4
			l_fr.rotation.x = -sin(step) * 0.4
			l_bl.rotation.x = -sin(step) * 0.35
			l_br.rotation.x = sin(step) * 0.35
			
			t_base.rotation = Vector3(0.5, -turn_angle * 0.4, 0)
			t_mid.rotation = Vector3(0.4, -turn_angle * 0.3, 0)
			t_tip.rotation = Vector3(0.3, -turn_angle * 0.2, 0)

# -----------------------------------------------------------------
# Standard Godot AnimationLibrary Generation
# -----------------------------------------------------------------
func _ensure_animation_library() -> void:
	if not is_instance_valid(animation_player): return
	if animation_player.has_animation_library(""): return
	
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _build_anim_idle())
	lib.add_animation("walk", _build_anim_walk())
	lib.add_animation("run", _build_anim_run())
	lib.add_animation("sit", _build_anim_sit())
	lib.add_animation("sleep", _build_anim_sleep())
	lib.add_animation("eat", _build_anim_eat())
	lib.add_animation("drink", _build_anim_drink())
	lib.add_animation("play", _build_anim_play())
	lib.add_animation("happy", _build_anim_happy())
	lib.add_animation("follow_turn", _build_anim_turn())
	lib.add_animation("turn", _build_anim_turn())
	
	animation_player.add_animation_library("", lib)

func _build_anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_body := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_body, "CatVisual/Root/Body:position")
	a.track_insert_key(t_body, 0.0, Vector3(0, 0.14, 0))
	a.track_insert_key(t_body, 1.0, Vector3(0, 0.146, 0))
	a.track_insert_key(t_body, 2.0, Vector3(0, 0.14, 0))
	
	var t_tail := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_tail, "CatVisual/Root/Body/TailBase:rotation")
	a.track_insert_key(t_tail, 0.0, Vector3(0.5, -0.15, 0))
	a.track_insert_key(t_tail, 1.0, Vector3(0.5, 0.15, 0))
	a.track_insert_key(t_tail, 2.0, Vector3(0.5, -0.15, 0))
	return a

func _build_anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.8
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_fl := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_fl, "CatVisual/Root/Body/LegFL:rotation")
	a.track_insert_key(t_fl, 0.0, Vector3(-0.45, 0, 0))
	a.track_insert_key(t_fl, 0.4, Vector3(0.45, 0, 0))
	a.track_insert_key(t_fl, 0.8, Vector3(-0.45, 0, 0))
	
	var t_fr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_fr, "CatVisual/Root/Body/LegFR:rotation")
	a.track_insert_key(t_fr, 0.0, Vector3(0.45, 0, 0))
	a.track_insert_key(t_fr, 0.4, Vector3(-0.45, 0, 0))
	a.track_insert_key(t_fr, 0.8, Vector3(0.45, 0, 0))
	return a

func _build_anim_run() -> Animation:
	var a := Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_fl := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_fl, "CatVisual/Root/Body/LegFL:rotation")
	a.track_insert_key(t_fl, 0.0, Vector3(-0.75, 0, 0))
	a.track_insert_key(t_fl, 0.25, Vector3(0.75, 0, 0))
	a.track_insert_key(t_fl, 0.5, Vector3(-0.75, 0, 0))
	return a

func _build_anim_sit() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_body := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_body, "CatVisual/Root/Body:position")
	a.track_insert_key(t_body, 0.0, Vector3(0, 0.08, 0))
	
	var t_rot := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_rot, "CatVisual/Root/Body:rotation")
	a.track_insert_key(t_rot, 0.0, Vector3(0.38, 0, 0))
	return a

func _build_anim_sleep() -> Animation:
	var a := Animation.new()
	a.length = 2.4
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_body := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_body, "CatVisual/Root/Body:position")
	a.track_insert_key(t_body, 0.0, Vector3(0, 0.05, 0))
	a.track_insert_key(t_body, 1.2, Vector3(0, 0.056, 0))
	a.track_insert_key(t_body, 2.4, Vector3(0, 0.05, 0))
	return a

func _build_anim_eat() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_head := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_head, "CatVisual/Root/Body/Head:position")
	a.track_insert_key(t_head, 0.0, Vector3(0, -0.04, 0.18))
	a.track_insert_key(t_head, 0.3, Vector3(0, -0.06, 0.19))
	a.track_insert_key(t_head, 0.6, Vector3(0, -0.04, 0.18))
	return a

func _build_anim_drink() -> Animation:
	var a := Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_head := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_head, "CatVisual/Root/Body/Head:position")
	a.track_insert_key(t_head, 0.0, Vector3(0, -0.05, 0.17))
	a.track_insert_key(t_head, 0.2, Vector3(0, -0.065, 0.17))
	a.track_insert_key(t_head, 0.4, Vector3(0, -0.05, 0.17))
	return a

func _build_anim_play() -> Animation:
	var a := Animation.new()
	a.length = 0.8
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_fl := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_fl, "CatVisual/Root/Body/LegFL:rotation")
	a.track_insert_key(t_fl, 0.0, Vector3(-0.6, 0, 0))
	a.track_insert_key(t_fl, 0.4, Vector3(0.5, 0, 0))
	a.track_insert_key(t_fl, 0.8, Vector3(-0.6, 0, 0))
	return a

func _build_anim_happy() -> Animation:
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_head := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_head, "CatVisual/Root/Body/Head:rotation")
	a.track_insert_key(t_head, 0.0, Vector3(-0.35, 0, 0))
	a.track_insert_key(t_head, 0.6, Vector3(-0.48, 0, 0))
	a.track_insert_key(t_head, 1.2, Vector3(-0.35, 0, 0))
	return a

func _build_anim_turn() -> Animation:
	var a := Animation.new()
	a.length = 0.8
	a.loop_mode = Animation.LOOP_LINEAR
	
	var t_head := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_head, "CatVisual/Root/Body/Head:rotation")
	a.track_insert_key(t_head, 0.0, Vector3(0, 0.35, 0))
	a.track_insert_key(t_head, 0.4, Vector3(0, -0.35, 0))
	a.track_insert_key(t_head, 0.8, Vector3(0, 0.35, 0))
	return a
