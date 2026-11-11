class_name DailyLoopManager
extends Node

const WorkplaceGuidance = preload("res://scripts/workplace_guidance.gd")
const DailySummaryDialog = preload("res://scripts/neighborhood/daily_summary_dialog.gd")
const PlayerScooter = preload("res://scripts/neighborhood/player_scooter.gd")

## Comprehensive coordinator for the Couple Chaos Daily Gameplay Loop:
## Wake Up → Leave House → Ride to Workplace → Open Shop → Serve Customers
## → Earn Money → Close Shop → Return Home → Sleep → Next Day.

signal day_started(day_number: int)
signal day_advanced(new_day: int)
signal phase_changed(old_phase: int, new_phase: int)
signal workplace_opened(shop: BusinessShop)
signal workplace_closed(shop: BusinessShop)
signal daily_summary_shown(summary_data: Dictionary)

enum Phase {
	WAKE_UP,          # Morning inside house
	COMMUTE_TO_WORK,  # Riding scooter to workplace
	OPEN_SHOP,        # Arrived at workplace, opening/preparing
	SERVING,          # Workplace open, serving arriving customers
	WORK_CLOSE,       # Closed workplace, shift complete
	RETURN_HOME,      # Riding scooter back to house
	SLEEP             # Resting on bed, transitioning to next day
}

@export var current_day: int = 1
@export var current_phase: Phase = Phase.WAKE_UP

# Daily accounting metrics
var daily_customers_served: int = 0
var daily_revenue: int = 0
var daily_expenses: int = 0
var daily_customers_lost: int = 0

var is_transitioning_day: bool = false
var is_closing_workplace: bool = false
var summary_shown_today: bool = false

var garage_business: GarageBusiness:
	set(v):
		garage_business = v
		_connect_business_signals()
var hutieu_business: HuTieuBusiness:
	set(v):
		hutieu_business = v
		_connect_business_signals()
var economy_manager: EconomyManager:
	set(v):
		economy_manager = v
var time_manager: NeighborhoodTimeManager:
	set(v):
		time_manager = v
		if is_instance_valid(time_manager):
			current_day = time_manager.current_day
			if not time_manager.day_advanced.is_connected(_on_time_manager_day_advanced):
				time_manager.day_advanced.connect(_on_time_manager_day_advanced)
var guidance: WorkplaceGuidance

var summary_dialog: DailySummaryDialog
var morning_toast: CanvasLayer
var toast_center: CenterContainer
var toast_label: Label

func _ready() -> void:
	add_to_group("daily_loop_manager")
	
	summary_dialog = DailySummaryDialog.new()
	summary_dialog.name = "DailySummaryDialog"
	add_child(summary_dialog)
	summary_dialog.dismissed.connect(_on_summary_dismissed)
	
	_build_morning_toast()
	_discover_dependencies()
	call_deferred("_discover_dependencies")

func _discover_dependencies() -> void:
	if not is_instance_valid(time_manager):
		time_manager = get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	if not is_instance_valid(economy_manager):
		economy_manager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if not is_instance_valid(garage_business):
		garage_business = get_tree().get_first_node_in_group("garage_business") as GarageBusiness
		if not garage_business:
			garage_business = get_node_or_null("../GarageBusiness") as GarageBusiness
	if not is_instance_valid(hutieu_business):
		hutieu_business = get_tree().get_first_node_in_group("hutieu_business") as HuTieuBusiness
		if not hutieu_business:
			hutieu_business = get_node_or_null("../HuTieuBusiness") as HuTieuBusiness
	if not is_instance_valid(guidance):
		guidance = get_tree().get_first_node_in_group("workplace_guidance") as WorkplaceGuidance
		if not guidance:
			guidance = get_node_or_null("../WorkplaceGuidance") as WorkplaceGuidance
	
	if is_instance_valid(time_manager):
		current_day = time_manager.current_day
		if not time_manager.day_advanced.is_connected(_on_time_manager_day_advanced):
			time_manager.day_advanced.connect(_on_time_manager_day_advanced)
	
	_connect_business_signals()

func _connect_business_signals() -> void:
	if is_instance_valid(garage_business):
		if not garage_business.order_completed.is_connected(_on_garage_order_completed):
			garage_business.order_completed.connect(_on_garage_order_completed)
		if not garage_business.shop_status_changed.is_connected(_on_garage_status_changed):
			garage_business.shop_status_changed.connect(_on_garage_status_changed)
	
	if is_instance_valid(hutieu_business):
		if not hutieu_business.order_completed.is_connected(_on_hutieu_order_completed):
			hutieu_business.order_completed.connect(_on_hutieu_order_completed)
		if not hutieu_business.shop_status_changed.is_connected(_on_hutieu_status_changed):
			hutieu_business.shop_status_changed.connect(_on_hutieu_status_changed)

func _on_garage_order_completed(_order: BusinessOrder, reward: int) -> void:
	daily_customers_served += 1
	daily_revenue += reward

func _on_hutieu_order_completed(_order: BusinessOrder, reward: int) -> void:
	daily_customers_served += 1
	daily_revenue += reward

func _on_garage_status_changed(is_open: bool) -> void:
	if is_transitioning_day: return
	if is_open:
		set_phase(Phase.SERVING)
		workplace_opened.emit(garage_business)
	else:
		if has_worked_today() and current_phase == Phase.SERVING:
			close_workplace(garage_business)

func _on_hutieu_status_changed(is_open: bool) -> void:
	if is_transitioning_day: return
	if is_open:
		set_phase(Phase.SERVING)
		workplace_opened.emit(hutieu_business)
	else:
		if has_worked_today() and current_phase == Phase.SERVING:
			close_workplace(hutieu_business)

func set_phase(new_phase: Phase) -> void:
	if current_phase == new_phase: return
	var old := current_phase
	current_phase = new_phase
	phase_changed.emit(old, new_phase)

func set_day(day: int) -> void:
	current_day = maxi(1, day)
	if is_instance_valid(time_manager):
		time_manager.current_day = current_day

func get_active_business(player_node: Node3D = null) -> BusinessShop:
	var p := player_node
	if not is_instance_valid(p):
		p = get_tree().get_first_node_in_group("players") as CharacterBody3D
	
	var char_name := "boy"
	if is_instance_valid(p):
		var char_val = p.get("selected_character")
		if char_val != null and str(char_val) != "":
			char_name = str(char_val)
	
	if char_name == "girl":
		return hutieu_business
	return garage_business

func open_workplace(shop: BusinessShop = null) -> bool:
	var target_shop := shop if is_instance_valid(shop) else get_active_business()
	if not is_instance_valid(target_shop): return false
	
	target_shop.open_shop()
	set_phase(Phase.SERVING)
	workplace_opened.emit(target_shop)
	return true

func close_workplace(shop: BusinessShop = null) -> Dictionary:
	if is_closing_workplace or is_transitioning_day:
		return get_daily_summary()
	is_closing_workplace = true
	
	var target_shop := shop if is_instance_valid(shop) else get_active_business()
	if is_instance_valid(target_shop) and target_shop.is_open:
		target_shop.close_shop()
	
	set_phase(Phase.RETURN_HOME)
	workplace_closed.emit(target_shop)
	
	var summary := get_daily_summary()
	if not summary_shown_today:
		summary_shown_today = true
		show_summary_dialog(summary)
	
	is_closing_workplace = false
	return summary

func get_daily_summary() -> Dictionary:
	var shop := get_active_business()
	var shop_title := shop.shop_name if is_instance_valid(shop) else "Cửa hàng"
	var wallet_bal := 0
	if is_instance_valid(economy_manager) and is_instance_valid(economy_manager.wallet):
		wallet_bal = economy_manager.wallet.balance
	
	var served := daily_customers_served
	var rev := daily_revenue
	if is_instance_valid(shop):
		served = maxi(served, shop.daily_customers_served)
		rev = maxi(rev, shop.daily_revenue)
	
	var exp_val := daily_expenses
	var prof := rev - exp_val
	
	return {
		"day": current_day,
		"customers_served": served,
		"revenue": rev,
		"expenses": exp_val,
		"profit": prof,
		"wallet_balance": wallet_bal,
		"shop_name": shop_title
	}

func show_summary_dialog(data: Dictionary = {}) -> void:
	var summary_data := data if not data.is_empty() else get_daily_summary()
	if is_instance_valid(summary_dialog):
		summary_dialog.show_summary(summary_data)
	daily_summary_shown.emit(summary_data)

func _on_summary_dismissed() -> void:
	set_phase(Phase.RETURN_HOME)
	if is_instance_valid(guidance):
		guidance._resolve_current_destination()

func record_expense(amount: int) -> void:
	if amount > 0:
		daily_expenses += amount

func record_revenue(amount: int) -> void:
	if amount > 0:
		daily_revenue += amount

func has_worked_today() -> bool:
	return daily_customers_served > 0 or daily_revenue > 0 or (current_phase >= Phase.WORK_CLOSE)

func is_ready_to_sleep() -> bool:
	return has_worked_today() or (is_instance_valid(time_manager) and (time_manager.current_hour >= 20.0 or time_manager.current_hour < 6.0))

func on_player_sleep(player_node: CharacterBody3D) -> bool:
	if is_transitioning_day:
		return false
	if not is_ready_to_sleep():
		return false
	
	is_transitioning_day = true
	
	# 1. Close any open shops safely
	if is_instance_valid(garage_business) and garage_business.is_open:
		garage_business.close_shop()
	if is_instance_valid(hutieu_business) and hutieu_business.is_open:
		hutieu_business.close_shop()
	
	# 2. Advance day counter and time
	if is_instance_valid(time_manager):
		time_manager.advance_to_next_day(7.0)
		current_day = time_manager.current_day
	else:
		current_day += 1
		day_advanced.emit(current_day)
	
	# 3. Reset daily business state cleanly
	if is_instance_valid(garage_business):
		garage_business.reset_daily_state()
	if is_instance_valid(hutieu_business):
		hutieu_business.reset_daily_state()
	
	daily_customers_served = 0
	daily_revenue = 0
	daily_expenses = 0
	daily_customers_lost = 0
	summary_shown_today = false
	
	# 4. Safely reposition commuter scooters at home parking bays
	_reset_scooters_to_home()
	
	# 5. Persist economy, house, and day to disk
	if is_instance_valid(economy_manager):
		economy_manager.save_economy_state()
	
	# 6. Morning wake-up
	set_phase(Phase.WAKE_UP)
	day_started.emit(current_day)
	
	show_morning_announcement()
	is_transitioning_day = false
	return true

func _reset_scooters_to_home() -> void:
	for sc in get_tree().get_nodes_in_group("player_scooters"):
		if sc is PlayerScooter:
			sc.global_position = sc.home_parking_pos
			sc.is_mounted = false
			sc.rider = null

func _on_time_manager_day_advanced(new_day: int) -> void:
	if current_day != new_day:
		current_day = new_day
		if not is_transitioning_day:
			day_advanced.emit(current_day)

func _build_morning_toast() -> void:
	morning_toast = CanvasLayer.new()
	morning_toast.name = "MorningToast"
	morning_toast.layer = 95
	morning_toast.visible = false
	add_child(morning_toast)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 30
	morning_toast.add_child(center)
	
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a262f")
	style.border_color = Color("69f0ae")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	toast_label = Label.new()
	toast_label.text = "☀️ CHÀO NGÀY MỚI!"
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_color_override("font_color", Color("ffd54f"))
	panel.add_child(toast_label)

func show_morning_announcement() -> void:
	if not is_instance_valid(morning_toast) or not is_instance_valid(toast_label): return
	toast_label.text = "☀️ CHÀO NGÀY MỚI — NGÀY %d!\nThức dậy, chuẩn bị đồ đạc và lên xe máy đến chỗ làm!" % current_day
	morning_toast.visible = true
	
	var tween := create_tween()
	morning_toast.offset = Vector2(0, -60)
	tween.tween_property(morning_toast, "offset:y", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.0)
	tween.tween_property(morning_toast, "offset:y", -80.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): morning_toast.visible = false)
