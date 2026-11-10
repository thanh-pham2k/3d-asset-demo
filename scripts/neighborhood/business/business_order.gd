class_name BusinessOrder
extends RefCounted

## Order representation for neighborhood businesses.
## Tracks service/dish requested, customer patience, sequence steps, and rewards.

enum Status {
	PENDING,
	IN_PROGRESS,
	COMPLETED,
	PAID,
	FAILED,
	CANCELLED
}

var order_id: String = ""
var customer_name: String = "Khách hàng"
var customer_node: Node3D = null
var service_type: String = ""
var service_title: String = ""
var reward_money: int = 25000

var patience_max: float = 50.0
var patience_remaining: float = 50.0
var status: Status = Status.PENDING

var required_steps: Array[String] = []
var completed_steps: Array[String] = []
var current_step_index: int = 0

# Spot or table where customer is waiting
var target_spot: Vector3 = Vector3.ZERO
var table_index: int = 0

func _init(p_id: String, p_type: String, p_title: String, p_reward: int, p_steps: Array = [], p_patience := 50.0) -> void:
	order_id = p_id
	service_type = p_type
	service_title = p_title
	reward_money = p_reward
	required_steps.clear()
	for s in p_steps:
		required_steps.append(str(s))
	completed_steps = []
	current_step_index = 0
	patience_max = p_patience
	patience_remaining = p_patience
	status = Status.PENDING

func get_current_required_step() -> String:
	if current_step_index < required_steps.size():
		return required_steps[current_step_index]
	return ""

func advance_step(step_name: String) -> bool:
	if status == Status.COMPLETED or status == Status.PAID:
		return false
	
	if current_step_index < required_steps.size():
		var expected := required_steps[current_step_index]
		if expected == step_name:
			completed_steps.append(step_name)
			current_step_index += 1
			status = Status.IN_PROGRESS
			if current_step_index >= required_steps.size():
				status = Status.COMPLETED
			return true
	return false

func get_progress_ratio() -> float:
	if required_steps.is_empty(): return 1.0
	return float(current_step_index) / float(required_steps.size())

func get_patience_ratio() -> float:
	if patience_max <= 0.0: return 1.0
	return clampf(patience_remaining / patience_max, 0.0, 1.0)
