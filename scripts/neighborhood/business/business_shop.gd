class_name BusinessShop
extends Node3D

## Base class for playable neighborhood businesses (Motorcycle Repair & Hu Tieu Shop).
## Handles order queues, customer patience, opening hours, revenue and feedback.

signal order_received(order: BusinessOrder)
signal order_step_done(order: BusinessOrder, step: String)
signal order_completed(order: BusinessOrder, reward: int)
signal order_failed(order: BusinessOrder, reason: String)
signal earnings_changed(total_earnings: int)
signal shop_status_changed(is_open: bool)
signal level_up(new_level: int)

@export var shop_id: String = "shop"
@export var shop_name: String = "Cửa hàng"
@export var open_hour: float = 6.0
@export var close_hour: float = 21.0
@export var auto_spawn_customers: bool = true
@export var spawn_interval: float = 16.0

var is_open: bool = true
var manual_closed: bool = false
var total_earnings: int = 0
var total_tips: int = 0
var customers_served: int = 0
var customers_lost: int = 0

# Daily statistics
var daily_revenue: int = 0
var daily_customers_served: int = 0
var daily_customers_lost: int = 0
var daily_expenses: int = 0

# Progression & Reputation
var business_level: int = 1 # 1 to 5
var reputation_score: float = 100.0 # 0.0 to 100.0
var streak_count: int = 0 # Consecutive successful orders

# Peak Hours
var is_peak_hour: bool = false
var peak_multiplier: float = 1.2 # +20% during rush hour

var active_orders: Array[BusinessOrder] = []
var completed_order_ids: Dictionary = {} # Prevent duplicate rewards

var spawn_timer: float = 2.0
var time_manager: NeighborhoodTimeManager
var status_billboard: Label3D

func _ready() -> void:
	time_manager = get_node_or_null("../TimeManager") as NeighborhoodTimeManager
	if not time_manager:
		time_manager = get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	
	if is_instance_valid(time_manager):
		time_manager.hour_ticked.connect(_on_hour_ticked)
		_check_operating_hours(time_manager.current_hour)
	
	_setup_status_billboard()

func _setup_status_billboard() -> void:
	status_billboard = Label3D.new()
	status_billboard.name = "ShopStatusBillboard"
	status_billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_billboard.font_size = 28
	status_billboard.pixel_size = 0.005
	status_billboard.outline_size = 8
	status_billboard.modulate = Color("fff59d")
	status_billboard.outline_modulate = Color("1a1a1a")
	status_billboard.position = Vector3(0, 3.2, 0)
	add_child(status_billboard)
	_update_status_display()

func _process(delta: float) -> void:
	if is_instance_valid(time_manager):
		_check_peak_hours(time_manager.current_hour)
	
	_update_orders_patience(delta)
	
	if is_open and auto_spawn_customers:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = get_effective_spawn_interval()
			_try_spawn_customer()
	
	_update_status_display()

func _get_peak_hour_ranges() -> Array[Vector2]:
	return [] # Subclasses override

func _check_peak_hours(hour: float) -> void:
	var ranges := _get_peak_hour_ranges()
	var in_peak := false
	for r in ranges:
		if hour >= r.x and hour < r.y:
			in_peak = true
			break
	is_peak_hour = in_peak

func get_effective_spawn_interval() -> float:
	var base := spawn_interval
	if business_level == 1:
		base *= 1.2 # Beginners get more breathing room
	elif business_level >= 3:
		base *= 0.9
	
	if is_peak_hour:
		base *= 0.65 # Faster arrivals in peak hour
	
	return maxf(6.0, base)

func get_patience_multiplier() -> float:
	match business_level:
		1: return 1.25 # Fair for beginners: +25% patience time
		2: return 1.15
		3: return 1.00
		4: return 0.95
		_: return 0.90

func _update_orders_patience(delta: float) -> void:
	var to_remove: Array[BusinessOrder] = []
	for order in active_orders:
		if order.status == BusinessOrder.Status.PENDING or order.status == BusinessOrder.Status.IN_PROGRESS:
			order.time_spent += delta
			order.patience_remaining -= delta
			if order.patience_remaining <= 0.0:
				order.status = BusinessOrder.Status.FAILED
				customers_lost += 1
				daily_customers_lost += 1
				streak_count = 0
				reputation_score = maxf(10.0, reputation_score - 4.0)
				order_failed.emit(order, "Hết thời gian chờ!")
				_show_feedback(order.target_spot, "Khách đã bỏ về vì chờ quá lâu! 💢", Color("ff5252"))
				to_remove.append(order)
	
	for order in to_remove:
		active_orders.erase(order)
		_on_customer_depart(order)

func complete_order(order: BusinessOrder) -> bool:
	if not active_orders.has(order):
		return false
	if completed_order_ids.has(order.order_id):
		return false # Prevent duplicate reward
	
	completed_order_ids[order.order_id] = true
	order.status = BusinessOrder.Status.PAID
	active_orders.erase(order)
	
	# Satisfaction and streak calculation
	var stars := order.get_star_rating()
	var rating_text := order.get_satisfaction_label()
	
	if stars >= 4:
		streak_count += 1
		reputation_score = minf(100.0, reputation_score + (2.5 if stars == 5 else 1.5))
		if stars == 5:
			order.tip_money = int(float(order.reward_money) * 0.20)
		else:
			order.tip_money = int(float(order.reward_money) * 0.10)
	else:
		streak_count = 0
		reputation_score = maxf(10.0, reputation_score - 1.0)
		order.tip_money = 0
	
	total_tips += order.tip_money
	total_earnings += order.reward_money
	customers_served += 1
	daily_revenue += order.reward_money
	daily_customers_served += 1
	
	# Business progression check
	if customers_served >= business_level * 4 and business_level < 5:
		business_level += 1
		level_up.emit(business_level)
		_show_feedback(global_position + Vector3(0, 3.0, 0), "🎉 Cửa hàng thăng hạng CẤP %d! ⭐" % business_level, Color("ffd54f"))
	
	earnings_changed.emit(total_earnings)
	order_completed.emit(order, order.reward_money)
	
	var streak_msg := (" 🔥 Chuỗi x%d!" % streak_count) if streak_count >= 3 else ""
	var tip_msg := (" (+%s đ Tip)" % format_money(order.tip_money)) if order.tip_money > 0 else ""
	_show_feedback(
		order.target_spot,
		"+%s đ · %s%s\n%s%s" % [
			format_money(order.reward_money),
			order.service_title,
			tip_msg,
			rating_text,
			streak_msg
		],
		Color("69f0ae")
	)
	
	_on_customer_depart(order)
	return true

func _on_hour_ticked(hour: int) -> void:
	_check_operating_hours(float(hour))

func _check_operating_hours(hour: float) -> void:
	var was_open := is_open
	var hours_open := false
	if open_hour <= close_hour:
		hours_open = (hour >= open_hour and hour < close_hour)
	else:
		hours_open = (hour >= open_hour or hour < close_hour)
	
	if not hours_open:
		manual_closed = false # Re-arm for tomorrow morning
		is_open = false
	elif not manual_closed:
		is_open = true
	else:
		is_open = false
	
	if was_open != is_open:
		shop_status_changed.emit(is_open)
		if not is_open:
			# Cancel pending orders when closed
			for order in active_orders.duplicate():
				order.status = BusinessOrder.Status.CANCELLED
				active_orders.erase(order)
				_on_customer_depart(order)
			_safe_clear_remaining_customers()

func open_shop() -> void:
	manual_closed = false
	is_open = true
	shop_status_changed.emit(true)
	_update_status_display()

func close_shop() -> void:
	manual_closed = true
	is_open = false
	shop_status_changed.emit(false)
	for order in active_orders.duplicate():
		order.status = BusinessOrder.Status.CANCELLED
		active_orders.erase(order)
		_on_customer_depart(order)
	_safe_clear_remaining_customers()
	_update_status_display()

func reset_daily_state() -> void:
	daily_revenue = 0
	daily_customers_served = 0
	daily_customers_lost = 0
	daily_expenses = 0
	manual_closed = false
	active_orders.clear()
	_update_status_display()

func _safe_clear_remaining_customers() -> void:
	pass

func _update_status_display() -> void:
	if not is_instance_valid(status_billboard): return
	if not is_open:
		status_billboard.text = "%s\n[ĐÃ ĐÓNG CỬA - MỞ LÚC %02d:00]" % [shop_name, int(open_hour)]
		status_billboard.modulate = Color("e0e0e0")
	else:
		var queue_count := active_orders.size()
		var peak_str := " | ⚡ CAO ĐIỂM" if is_peak_hour else ""
		var streak_str := " | 🔥x%d" % streak_count if streak_count >= 2 else ""
		status_billboard.text = "%s (Cấp %d%s)\nDoanh thu: %s đ | Khách chờ: %d%s" % [
			shop_name,
			business_level,
			peak_str,
			format_money(total_earnings),
			queue_count,
			streak_str
		]
		status_billboard.modulate = Color("fff59d")

func _show_feedback(pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.position = pos + Vector3(0, 1.8, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.005
	label.outline_size = 8
	label.modulate = color
	label.text = text
	get_parent().add_child(label)
	
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 1.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.8)
	tween.tween_callback(label.queue_free)

func format_money(val: int) -> String:
	var s := str(val)
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

# Virtual methods for subclasses:
func _try_spawn_customer() -> void:
	pass

func _on_customer_depart(_order: BusinessOrder) -> void:
	pass
