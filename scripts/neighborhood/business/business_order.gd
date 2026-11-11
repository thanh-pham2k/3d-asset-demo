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

var satisfaction: float = 1.0 # 0.0 to 1.0
var mistake_count: int = 0
var tip_money: int = 0
var time_spent: float = 0.0
var is_peak_hour: bool = false
var peak_bonus: int = 0

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
	satisfaction = 1.0
	mistake_count = 0
	tip_money = 0
	time_spent = 0.0
	is_peak_hour = false
	peak_bonus = 0

func record_mistake(penalty := 0.15) -> void:
	mistake_count += 1
	satisfaction = maxf(0.15, satisfaction - penalty)

func calculate_satisfaction() -> float:
	var patience_factor := get_patience_ratio()
	# Satisfaction considers remaining patience and mistakes made
	var score := (patience_factor * 0.7) + (satisfaction * 0.3)
	if mistake_count > 0:
		score = maxf(0.1, score - (mistake_count * 0.1))
	return clampf(score, 0.0, 1.0)

func get_star_rating() -> int:
	var s := calculate_satisfaction()
	if s >= 0.85: return 5
	elif s >= 0.65: return 4
	elif s >= 0.45: return 3
	elif s >= 0.25: return 2
	else: return 1

func get_satisfaction_label() -> String:
	match get_star_rating():
		5: return "Tuyệt vời ⭐⭐⭐⭐⭐"
		4: return "Hài lòng ⭐⭐⭐⭐"
		3: return "Bình thường ⭐⭐⭐"
		2: return "Thất vọng ⭐⭐"
		_: return "Tệ ⭐"

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
