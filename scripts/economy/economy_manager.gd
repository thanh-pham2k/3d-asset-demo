class_name EconomyManager
extends Node

## Central coordinator for Couple Chaos economy.
## Manages the shared household wallet, inventory, product purchases,
## business reward deposits, and persistence.

signal purchase_completed(product: EconomyProduct, count: int, total_cost: int)
signal purchase_failed(product_id: String, reason: String, message: String)

@export var save_file_path: String = EconomySaveSystem.DEFAULT_SAVE_PATH
@export var auto_save_on_change: bool = true

var wallet: HouseholdWallet
var inventory: InventoryManager
var catalog: Dictionary = {}

var garage_business: Node
var hutieu_business: Node
var house_manager: Node

func _init() -> void:
	wallet = HouseholdWallet.new()
	inventory = InventoryManager.new()
	catalog = EconomyProduct.create_default_catalog()

func apply_all_owned_upgrades() -> void:
	for upg_id in inventory.get_all_owned_upgrades():
		var prod: EconomyProduct = get_product(upg_id)
		if prod:
			_apply_upgrade_effect(prod)


func _ready() -> void:
	add_to_group("economy_manager")
	
	# Load persistent save if available
	load_economy_state()
	
	# Auto-discover businesses
	call_deferred("_connect_businesses")

func _connect_businesses() -> void:
	if not is_instance_valid(garage_business):
		garage_business = get_node_or_null("../GarageBusiness")
	if not is_instance_valid(hutieu_business):
		hutieu_business = get_node_or_null("../HuTieuBusiness")
	
	if is_instance_valid(garage_business):
		if not garage_business.order_completed.is_connected(_on_garage_order_completed):
			garage_business.order_completed.connect(_on_garage_order_completed)
	
	if is_instance_valid(hutieu_business):
		if not hutieu_business.order_completed.is_connected(_on_hutieu_order_completed):
			hutieu_business.order_completed.connect(_on_hutieu_order_completed)
			
	apply_all_owned_upgrades()

func _on_garage_order_completed(order: BusinessOrder, reward: int) -> void:
	var tx_id := "garage_order_%s" % order.order_id
	var desc := "Sửa xe: %s (%s)" % [order.service_title, order.customer_name]
	wallet.deposit(reward, "garage_revenue", desc, tx_id)
	if auto_save_on_change: save_economy_state()

func _on_hutieu_order_completed(order: BusinessOrder, reward: int) -> void:
	var tx_id := "hutieu_order_%s" % order.order_id
	var desc := "Bán hủ tiếu: %s (%s)" % [order.service_title, order.customer_name]
	wallet.deposit(reward, "hutieu_revenue", desc, tx_id)
	if auto_save_on_change: save_economy_state()

func get_product(product_id: String) -> EconomyProduct:
	return catalog.get(product_id, null)

func get_products_by_category(category: String) -> Array[EconomyProduct]:
	var result: Array[EconomyProduct] = []
	for prod in catalog.values():
		if prod.category == category:
			result.append(prod)
	return result

func purchase_product(product_id: String, count := 1) -> Dictionary:
	var product: EconomyProduct = get_product(product_id)
	if not product:
		var err := { "success": false, "reason": "NOT_FOUND", "message": "Không tìm thấy mặt hàng này!" }
		purchase_failed.emit(product_id, err["reason"], err["message"])
		return err
	
	if product.is_unique:
		count = 1
		# Check if already owned
		if product.category == "furniture" and inventory.is_furniture_owned(product.id):
			var err := { "success": false, "reason": "ALREADY_OWNED", "message": "Bạn đã sở hữu món đồ này!" }
			purchase_failed.emit(product_id, err["reason"], err["message"])
			return err
		elif (product.category == "business_upgrade" or product.category == "house_upgrade") and inventory.is_upgrade_owned(product.id):
			var err := { "success": false, "reason": "ALREADY_OWNED", "message": "Nâng cấp này đã được kích hoạt!" }
			purchase_failed.emit(product_id, err["reason"], err["message"])
			return err
	
	var total_cost := product.price * count
	if not wallet.can_afford(total_cost):
		var err := {
			"success": false,
			"reason": "INSUFFICIENT_FUNDS",
			"message": "Không đủ tiền trong ví gia đình! Cần %s đ (Hiện có: %s đ)" % [
				HouseholdWallet.format_money(total_cost),
				HouseholdWallet.format_money(wallet.balance)
			]
		}
		purchase_failed.emit(product_id, err["reason"], err["message"])
		return err
	
	# Execute transaction
	var tx_id := "buy_%s_%d_%d" % [product_id, Time.get_ticks_usec(), randi() % 1000000]
	var tx_desc := "Mua: %s x%d" % [product.name, count]
	var ok := wallet.withdraw(total_cost, product.category, tx_desc, tx_id)
	if not ok:
		var err := { "success": false, "reason": "PAYMENT_FAILED", "message": "Giao dịch không thành công!" }
		purchase_failed.emit(product_id, err["reason"], err["message"])
		return err
	
	# Add to inventory / unlock ownership
	if product.category == "furniture":
		inventory.unlock_furniture(product.id, count, not product.is_unique)
		if is_instance_valid(house_manager) and "storage" in house_manager and house_manager.storage:
			var placed_list: Array = house_manager.progression_manager.placed_furniture if "progression_manager" in house_manager else []
			house_manager.storage.sync_with_inventory(inventory, placed_list)
	elif product.category == "business_upgrade" or product.category == "house_upgrade":
		inventory.unlock_upgrade(product.id)
		_apply_upgrade_effect(product)
	else:
		# Consumable item
		inventory.add_item(product.id, count)
	
	if is_inside_tree() and get_tree():
		var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(daily_loop) and daily_loop.has_method("record_expense"):
			daily_loop.record_expense(total_cost)
	
	if auto_save_on_change:
		save_economy_state()
	
	var success_res := {
		"success": true,
		"product": product,
		"count": count,
		"total_cost": total_cost,
		"message": "Mua thành công: %s!" % product.name
	}
	purchase_completed.emit(product, count, total_cost)
	return success_res

func _apply_upgrade_effect(product: EconomyProduct) -> void:
	if not product: return
	match product.id:
		# Garage upgrades
		"upg_garage_second_bay":
			if is_instance_valid(garage_business) and garage_business.has_method("apply_second_bay_upgrade"):
				garage_business.apply_second_bay_upgrade()
		"upg_garage_tools":
			if is_instance_valid(garage_business) and garage_business.has_method("apply_better_tools_upgrade"):
				garage_business.apply_better_tools_upgrade()
		"upg_garage_compressor":
			if is_instance_valid(garage_business) and garage_business.has_method("apply_compressor_upgrade"):
				garage_business.apply_compressor_upgrade()
		
		# Hu Tieu upgrades
		"upg_hutieu_extra_table":
			if is_instance_valid(hutieu_business) and hutieu_business.has_method("apply_extra_table_upgrade"):
				hutieu_business.apply_extra_table_upgrade()
		"upg_hutieu_quick_stove":
			if is_instance_valid(hutieu_business) and hutieu_business.has_method("apply_quick_stove_upgrade"):
				hutieu_business.apply_quick_stove_upgrade()
		"upg_hutieu_kitchen_capacity":
			if is_instance_valid(hutieu_business) and hutieu_business.has_method("apply_kitchen_capacity_upgrade"):
				hutieu_business.apply_kitchen_capacity_upgrade()
				
		# House upgrades
		"upg_house_level_2":
			if is_instance_valid(house_manager):
				if "progression_manager" in house_manager and house_manager.progression_manager.house_level < 2:
					house_manager.progression_manager.house_level = 2
					house_manager.progression_manager._update_unlocked_areas()
					if house_manager.has_method("rebuild_house"):
						house_manager.rebuild_house()
		"upg_house_level_3":
			if is_instance_valid(house_manager):
				if "progression_manager" in house_manager and house_manager.progression_manager.house_level < 3:
					house_manager.progression_manager.house_level = 3
					house_manager.progression_manager._update_unlocked_areas()
					if house_manager.has_method("rebuild_house"):
						house_manager.rebuild_house()


func get_goal_info() -> Dictionary:
	var total_earned := wallet.total_earned
	var house_lvl: int = 1
	if is_instance_valid(house_manager) and "progression_manager" in house_manager:
		house_lvl = house_manager.progression_manager.house_level
	elif inventory.is_upgrade_owned("upg_house_level_3"):
		house_lvl = 3
	elif inventory.is_upgrade_owned("upg_house_level_2"):
		house_lvl = 2
		
	# Goal 1: First earnings milestone
	if total_earned < 100000:
		return {
			"id": "goal_first_earnings",
			"title": "Khởi Nghiệp Phát Tài",
			"description": "Phục vụ khách hàng tại Tiệm Sửa Xe và Quán Hủ Tiếu",
			"target": 100000,
			"current": total_earned,
			"unit": "đ thu nhập",
			"next_upgrade_id": "upg_house_level_2",
			"next_upgrade_cost": 75000,
			"next_upgrade_name": "Nhà Cấp 2 — Căn hộ ấm cúng",
			"is_ready_to_buy": wallet.balance >= 75000,
			"hint": "Đã đủ tiền mua Nhà Cấp 2! Đến Bảng Nâng Cấp" if wallet.balance >= 75000 else "Tiếp tục tích lũy thêm %s" % HouseholdWallet.format_money(75000 - wallet.balance)
		}
	
	# Goal 2: Upgrade House to Level 2
	if house_lvl < 2:
		return {
			"id": "goal_house_lvl_2",
			"title": "Tổ Ấm Ấm Cúng",
			"description": "Nâng cấp ngôi nhà lên Cấp 2 (Mở rộng phòng khách và gian bếp)",
			"target": 75000,
			"current": wallet.balance,
			"unit": "đ trong ví",
			"next_upgrade_id": "upg_house_level_2",
			"next_upgrade_cost": 75000,
			"next_upgrade_name": "Nhà Cấp 2 — Căn hộ ấm cúng",
			"is_ready_to_buy": wallet.balance >= 75000,
			"hint": "Đã đủ tiền nâng cấp nhà Cấp 2!" if wallet.balance >= 75000 else "Cần tích lũy thêm %s" % HouseholdWallet.format_money(75000 - wallet.balance)
		}
	
	# Goal 3: First business upgrade
	var has_first_biz_upg := (inventory.is_upgrade_owned("upg_garage_tools") or inventory.is_upgrade_owned("upg_hutieu_quick_stove"))
	if not has_first_biz_upg:
		var target_upg := "upg_garage_tools"
		var cost := 80000
		var name_str := "Bộ đồ nghề sửa xe cao cấp"
		if inventory.is_upgrade_owned("upg_garage_tools"):
			target_upg = "upg_hutieu_quick_stove"
			cost = 100000
			name_str = "Bếp trụng áp suất cao"
		return {
			"id": "goal_first_business_upgrade",
			"title": "Nâng Cấp Thiết Bị",
			"description": "Tái đầu tư: Trang bị %s" % name_str,
			"target": cost,
			"current": wallet.balance,
			"unit": "đ trong ví",
			"next_upgrade_id": target_upg,
			"next_upgrade_cost": cost,
			"next_upgrade_name": name_str,
			"is_ready_to_buy": wallet.balance >= cost,
			"hint": "Đã đủ tiền! Mua tại Kiosk tiệm kinh doanh" if wallet.balance >= cost else "Cần thêm %s" % HouseholdWallet.format_money(cost - wallet.balance)
		}
	
	# Goal 4: Capacity expansion (Second Bay or 4th Table)
	var has_capacity_upg := (inventory.is_upgrade_owned("upg_garage_second_bay") or inventory.is_upgrade_owned("upg_hutieu_extra_table"))
	if not has_capacity_upg:
		return {
			"id": "goal_expand_capacity",
			"title": "Mở Rộng Quy Mô",
			"description": "Mở Khoang sửa xe thứ 2 (150.000 đ) hoặc Bàn ăn thứ 4 (120.000 đ)",
			"target": 120000,
			"current": wallet.balance,
			"unit": "đ trong ví",
			"next_upgrade_id": "upg_hutieu_extra_table",
			"next_upgrade_cost": 120000,
			"next_upgrade_name": "Bàn ăn ngoài trời thứ 4",
			"is_ready_to_buy": wallet.balance >= 120000,
			"hint": "Đã đủ tiền mở rộng kinh doanh!" if wallet.balance >= 120000 else "Cần thêm %s" % HouseholdWallet.format_money(120000 - wallet.balance)
		}
	
	# Goal 5: House Level 3 (Biệt thự sân vườn)
	if house_lvl < 3:
		return {
			"id": "goal_house_lvl_3",
			"title": "Biệt Thự Mơ Ước",
			"description": "Nâng cấp nhà Cấp 3: Phòng đọc sách ngắm cảnh và sân vườn",
			"target": 150000,
			"current": wallet.balance,
			"unit": "đ trong ví",
			"next_upgrade_id": "upg_house_level_3",
			"next_upgrade_cost": 150000,
			"next_upgrade_name": "Nhà Cấp 3 — Biệt thự sân vườn",
			"is_ready_to_buy": wallet.balance >= 150000,
			"hint": "Đã đủ tiền! Nâng cấp nhà tại Bảng Nâng Cấp" if wallet.balance >= 150000 else "Cần thêm %s" % HouseholdWallet.format_money(150000 - wallet.balance)
		}
		
	# Goal 6: Grand Master (All upgrades completed)
	return {
		"id": "goal_mastery",
		"title": "Cuộc Sống Viên Mãn",
		"description": "Gia đình phát đạt, ngôi nhà khang trang và hai tiệm kinh doanh thịnh vượng!",
		"target": 100,
		"current": 100,
		"unit": "% hoàn thành",
		"next_upgrade_id": "",
		"next_upgrade_cost": 0,
		"next_upgrade_name": "Đã đạt cấp tối đa",
		"is_ready_to_buy": false,
		"hint": "Chúc mừng! Đã đạt toàn bộ mục tiêu nâng cấp lớn!"
	}

func save_economy_state(path := "") -> bool:
	var p := path if path != "" else save_file_path
	var b_data := {}
	if is_instance_valid(garage_business):
		b_data["garage_earnings"] = garage_business.total_earnings
		b_data["garage_served"] = garage_business.customers_served
	if is_instance_valid(hutieu_business):
		b_data["hutieu_earnings"] = hutieu_business.total_earnings
		b_data["hutieu_served"] = hutieu_business.customers_served
	
	if is_inside_tree() and get_tree():
		var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(daily_loop) and "current_day" in daily_loop:
			b_data["day"] = daily_loop.current_day
		else:
			var time_mgr = get_tree().get_first_node_in_group("time_manager")
			if is_instance_valid(time_mgr) and "current_day" in time_mgr:
				b_data["day"] = time_mgr.current_day
	
	var h_data := {}
	if is_instance_valid(house_manager) and house_manager.has_method("get_save_data"):
		h_data = house_manager.get_save_data()
	
	return EconomySaveSystem.save_economy(wallet, inventory, b_data, h_data, p)

func load_economy_state(path := "") -> bool:
	var p := path if path != "" else save_file_path
	var b_data := EconomySaveSystem.load_economy(wallet, inventory, p)
	
	if is_instance_valid(garage_business) and b_data.has("garage_earnings"):
		garage_business.total_earnings = int(b_data["garage_earnings"])
		garage_business.customers_served = int(b_data["garage_served"])
	if is_instance_valid(hutieu_business) and b_data.has("hutieu_earnings"):
		hutieu_business.total_earnings = int(b_data["hutieu_earnings"])
		hutieu_business.customers_served = int(b_data["hutieu_served"])
	
	if b_data.has("day") and is_inside_tree() and get_tree():
		var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(daily_loop) and daily_loop.has_method("set_day"):
			daily_loop.set_day(int(b_data["day"]))
		var time_mgr = get_tree().get_first_node_in_group("time_manager")
		if is_instance_valid(time_mgr) and "current_day" in time_mgr:
			time_mgr.current_day = int(b_data["day"])
	
	if is_instance_valid(house_manager) and b_data.has("house") and house_manager.has_method("apply_save_data"):
		house_manager.apply_save_data(b_data["house"])
		
	apply_all_owned_upgrades()
	
	return true
