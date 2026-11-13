class_name DualConfirmationManager
extends Node

## Handles 2-player mutual confirmation for major household purchases and upgrades.
## Ensures that high-value transactions require agreement from both Player 1 and Player 2.
## Automatically grants single-player purchases if co-op is inactive.

signal confirmation_requested(initiator_id: int, product_name: String, cost: int)
signal confirmation_approved(initiator_id: int, product_name: String, cost: int)
signal confirmation_declined(initiator_id: int, product_name: String, reason: String)

var is_coop_active: bool = false
var active_request: Dictionary = {}
var timer: float = 0.0
const TIMEOUT_DURATION: float = 12.0

func _ready() -> void:
	add_to_group("dual_confirmation_manager")

func has_pending_request() -> bool:
	return not active_request.is_empty()

func request_purchase(
	initiator_id: int,
	product_name: String,
	cost: int,
	on_approved: Callable,
	threshold: int = 50000
) -> bool:
	# Verify funds first if EconomyManager is present in the tree
	if is_inside_tree():
		var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if is_instance_valid(econ) and is_instance_valid(econ.wallet):
			if not econ.wallet.can_afford(cost):
				confirmation_declined.emit(initiator_id, product_name, "INSUFFICIENT_FUNDS")
				return false

	# If not co-op or cost is under threshold, approve immediately
	if not is_coop_active or cost < threshold:
		if on_approved.is_valid():
			on_approved.call()
		confirmation_approved.emit(initiator_id, product_name, cost)
		return true
	
	# Cancel any existing request
	if has_pending_request():
		cancel_request("NEW_REQUEST_OVERRIDE")
	
	var other_id := 2 if initiator_id == 1 else 1
	active_request = {
		"initiator_id": initiator_id,
		"other_id": other_id,
		"product_name": product_name,
		"cost": cost,
		"callback": on_approved,
		"status": "PENDING"
	}
	timer = TIMEOUT_DURATION
	
	confirmation_requested.emit(initiator_id, product_name, cost)
	return false

func _process(delta: float) -> void:
	if not has_pending_request(): return
	
	timer -= delta
	if timer <= 0.0:
		cancel_request("TIMEOUT")
		return
	
	var other_id: int = active_request["other_id"]
	var prefix := "p%d_" % other_id
	
	if Input.is_action_just_pressed(prefix + "confirm") or Input.is_action_just_pressed(prefix + "interact"):
		approve_request()
	elif Input.is_action_just_pressed(prefix + "cancel") or Input.is_action_just_pressed(prefix + "throw"):
		cancel_request("DECLINED_BY_PARTNER")

func approve_request() -> void:
	if not has_pending_request(): return
	
	var req := active_request
	active_request = {}
	
	# Re-verify funds at moment of approval
	if is_inside_tree():
		var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if is_instance_valid(econ) and is_instance_valid(econ.wallet):
			if not econ.wallet.can_afford(req["cost"]):
				confirmation_declined.emit(req["initiator_id"], req["product_name"], "INSUFFICIENT_FUNDS")
				return

	if req.get("callback", Callable()).is_valid():
		req["callback"].call()
		
	confirmation_approved.emit(req["initiator_id"], req["product_name"], req["cost"])

func cancel_request(reason: String) -> void:
	if not has_pending_request(): return
	
	var req := active_request
	active_request = {}
	
	confirmation_declined.emit(req["initiator_id"], req["product_name"], reason)

func get_prompt_text() -> String:
	if not has_pending_request(): return ""
	var p_name: String = active_request["product_name"]
	var cost: int = active_request["cost"]
	var other_id: int = active_request["other_id"]
	var btn_hint := CoopInputManager.get_player_button_hint(other_id, "interact")
	var cancel_hint := CoopInputManager.get_player_button_hint(other_id, "throw")
	
	return "🤝 P%d muốn mua '%s' (%s)\n👉 P%d nhấn [%s] để Đồng ý  ·  [%s] để Từ chối (%ds)" % [
		active_request["initiator_id"],
		p_name,
		HouseholdWallet.format_money(cost),
		other_id,
		btn_hint,
		cancel_hint,
		int(ceil(timer))
	]
