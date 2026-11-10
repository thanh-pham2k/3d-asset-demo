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

@export var shop_id: String = "shop"
@export var shop_name: String = "Cửa hàng"
@export var open_hour: float = 6.0
@export var close_hour: float = 21.0
@export var auto_spawn_customers: bool = true
@export var spawn_interval: float = 16.0

var is_open: bool = true
var total_earnings: int = 0
var customers_served: int = 0
var customers_lost: int = 0

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
	_update_orders_patience(delta)
	
	if is_open and auto_spawn_customers:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval
			_try_spawn_customer()
	
	_update_status_display()

func _update_orders_patience(delta: float) -> void:
	var to_remove: Array[BusinessOrder] = []
	for order in active_orders:
		if order.status == BusinessOrder.Status.PENDING or order.status == BusinessOrder.Status.IN_PROGRESS:
			order.patience_remaining -= delta
			if order.patience_remaining <= 0.0:
				order.status = BusinessOrder.Status.FAILED
				customers_lost += 1
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
	
	total_earnings += order.reward_money
	customers_served += 1
	earnings_changed.emit(total_earnings)
	order_completed.emit(order, order.reward_money)
	
	_show_feedback(order.target_spot, "+%s đ (%s)" % [format_money(order.reward_money), order.service_title], Color("69f0ae"))
	_on_customer_depart(order)
	return true

func _on_hour_ticked(hour: int) -> void:
	_check_operating_hours(float(hour))

func _check_operating_hours(hour: float) -> void:
	var was_open := is_open
	if open_hour <= close_hour:
		is_open = (hour >= open_hour and hour < close_hour)
	else:
		is_open = (hour >= open_hour or hour < close_hour)
	
	if was_open != is_open:
		shop_status_changed.emit(is_open)
		if not is_open:
			# Cancel pending orders when closed
			for order in active_orders.duplicate():
				order.status = BusinessOrder.Status.CANCELLED
				active_orders.erase(order)
				_on_customer_depart(order)

func _update_status_display() -> void:
	if not is_instance_valid(status_billboard): return
	if not is_open:
		status_billboard.text = "%s\n[ĐÃ ĐÓNG CỬA - MỞ LÚC %02d:00]" % [shop_name, int(open_hour)]
		status_billboard.modulate = Color("e0e0e0")
	else:
		var queue_count := active_orders.size()
		status_billboard.text = "%s\nDoanh thu: %s đ | Khách đang chờ: %d" % [
			shop_name,
			format_money(total_earnings),
			queue_count
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
