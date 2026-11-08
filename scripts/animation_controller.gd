extends Node

var model: Node3D
var state := "idle"
var previous_holding := false
var pickup_until := 0.0
var recovery_until := 0.0
var last_reacting := false
var previous_yaw := 0.0
var first_update := true
var hammer_until := 0.0
var reaction_started := 0.0

func trigger_action(action: String, time: float) -> void:
 if action == "hammer": hammer_until = time + 0.35
 if is_instance_valid(model) and model.has_method("trigger_action"):
  model.trigger_action(action, time)

# Common model adapter interface; independent visual scenes can implement update_pose.
func apply_state(move: float, running: bool, holding: bool, throwing: bool, resting: bool, lying: bool, reacting: bool, time: float) -> void:
 if model.has_method("update_pose"):
  model.update_pose(move, running, holding, throwing, resting, lying, reacting, time)
 elif "left_arm" in model:
  update_placeholder(move, running, holding, throwing, resting, lying, reacting, time)

func update_placeholder(move: float, running: bool, holding: bool, throwing: bool, resting: bool, lying: bool, reacting: bool, time: float) -> void:
 if holding and not previous_holding:
  pickup_until = time + 0.24
 if reacting and not last_reacting:
  reaction_started = time
 if last_reacting and not reacting:
  recovery_until = time + 0.35
 previous_holding = holding
 last_reacting = reacting
 var yaw := model.get_parent_node_3d().rotation.y
 var turning := not first_update and absf(angle_difference(previous_yaw, yaw)) > 0.035
 previous_yaw = yaw
 first_update = false
 state = "idle"
 if move > 0.05: state = "run" if running else "walk"
 if turning and move > 0.05: state = "turn"
 if holding: state = "carry" if move > 0.05 else "hold"
 if holding and time < pickup_until: state = "pickup"
 if throwing: state = "throw"
 if time < hammer_until: state = "hammer_swing"
 if reacting:
  var elapsed := time - reaction_started
  state = "hit" if elapsed < 0.12 else ("knockback" if elapsed < 0.3 else "fall")
 elif time < recovery_until: state = "get_up"
 if resting: state = "lie" if lying else "sit"
 var swing := sin(time * (13.0 if running else 8.0)) * move
 var left_leg_angle := swing * 0.62
 var right_leg_angle := -swing * 0.62
 var left_arm_angle := -swing * 0.55
 var right_arm_angle := swing * 0.55
 var head_pitch := 0.0
 if holding:
  left_arm_angle = -1.15
  right_arm_angle = -1.15
 if state == "pickup":
  left_arm_angle = -0.6
  right_arm_angle = -0.6
  head_pitch = 0.12
 if throwing:
  right_arm_angle = -2.1
  left_arm_angle = -0.5
 if state == "hammer_swing":
  right_arm_angle = -2.2 if time < hammer_until - 0.17 else -0.3
 if resting:
  left_leg_angle = -1.25 if not lying else 0.0
  right_leg_angle = left_leg_angle
 if model.has_method("pose_joint"):
  model.pose_joint("root", Vector3(0,0,swing * 0.035))
  model.pose_joint("head", Vector3(head_pitch,0,sin(time * 3.0) * 0.025))
  model.pose_joint("left_leg", Vector3(left_leg_angle,0,0))
  model.pose_joint("right_leg", Vector3(right_leg_angle,0,0))
  model.pose_joint("left_arm", Vector3(left_arm_angle,0,0))
  model.pose_joint("right_arm", Vector3(right_arm_angle,0,0))
 else:
  model.left_leg.rotation.x = left_leg_angle
  model.right_leg.rotation.x = right_leg_angle
  model.left_arm.rotation.x = left_arm_angle
  model.right_arm.rotation.x = right_arm_angle
 var bob := sin(time * 3.0) * 0.015
 model.scale = Vector3(1.0-bob*0.4, 1.0+bob, 1.0-bob*0.4)
 model.rotation.z = 0.0
 model.rotation.x = -0.8 if state == "fall" else 0.0
 if state == "get_up": model.rotation.x = -0.8 * clampf((recovery_until-time)/0.35,0.0,1.0)
 if reacting:
  model.scale = Vector3(1.18,0.84,1.18)
  model.rotation.z = sin(time*30.0)*0.18
 elif time < recovery_until:
  var strength := clampf((recovery_until-time)/0.22, 0.0, 1.0)
  model.scale = Vector3(1.0+0.10*strength,1.0-0.10*strength,1.0+0.10*strength)
 if model.has_method("set_expression"):
  var face := ("dizzy" if state == "fall" else "hurt") if reacting else ("surprised" if throwing else "happy")
  if model.expression != face: model.set_expression(face)
