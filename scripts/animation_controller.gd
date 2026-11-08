extends Node

var model: Node3D

func apply_state(move: float, running: bool, holding: bool, throwing: bool, resting: bool, lying: bool, reacting: bool, time: float) -> void:
 if model.has_method("update_pose"):
  model.update_pose(move, running, holding, throwing, resting, lying, reacting, time)
 elif "left_arm" in model:
  update_placeholder(move, running, holding, throwing, resting, lying, reacting, time)

func update_placeholder(move: float, running: bool, holding: bool, throwing: bool, resting: bool, lying: bool, reacting: bool, time: float) -> void:
 var swing = sin(time * (13.0 if running else 8.0)) * move
 model.left_leg.rotation.x = swing * 0.62
 model.right_leg.rotation.x = -swing * 0.62
 model.left_arm.rotation.x = -swing * 0.55
 model.right_arm.rotation.x = swing * 0.55
 if holding:
  model.left_arm.rotation.x = -1.15
  model.right_arm.rotation.x = -1.15
 if throwing: model.right_arm.rotation.x = -2.1
 if resting:
  model.left_leg.rotation.x = -1.25 if not lying else 0.0
  model.right_leg.rotation.x = model.left_leg.rotation.x
 model.scale = Vector3(1,1+sin(time*3.0)*0.015,1)
 if reacting:
  model.scale = Vector3(1.18,0.84,1.18)
  model.rotation.z = sin(time*30)*0.18
 else: model.rotation.z = 0

