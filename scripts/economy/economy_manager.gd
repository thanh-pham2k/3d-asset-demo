class_name EconomyManager
extends Node

## Central coordinator for Couple Chaos economy.
## Manages the shared household wallet, inventory, product purchases,
## business reward deposits, and persistence.

signal purchase_completed(product: EconomyProduct, count: int, total_cost: int)
signal purchase_failed(product_id: String, reason: String, message: String)
signal produce_sold(product: EconomyProduct, count: int, total_earned: int)
signal save_failed(path: String)

@export var save_file_path: String = EconomySaveSystem.DEFAULT_SAVE_PATH
@export var auto_save_on_change: bool = true

var wallet: HouseholdWallet
var inventory: InventoryManager
var catalog: Dictionary = {}

var garage_business: Node
var hutieu_business: Node
var house_manager: Node
var _save_failure_reported := false
var pending_daily_state: Dictionary = {}

func _init() -> void:
	wallet = HouseholdWallet.new()
	inventory = InventoryManager.new()
	catalog = EconomyProduct.create_default_catalog()

func _ensure_house_manager() -> void:
	if not is_instance_valid(house_manager) and is_inside_tree():
		house_manager = get_tree().get_first_node_in_group("house_manager")
		if not is_instance_valid(house_manager):
			house_manager = get_tree().get_first_node_in_group("room")

func apply_all_owned_upgrades() -> void:
	_ensure_house_manager()
	for upg_id in inventory.get_all_owned_upgrades():
		var prod: EconomyProduct = get_product(upg_id)
		if prod:
			_apply_upgrade_effect(prod)


func _ready() -> void:
	add_to_group("economy_manager")
	
	# Starter supplies are granted once, only when no save or backup exists.
	var save_path := EconomySaveSystem.get_effective_path(save_file_path)
	var is_new_game := not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak")
	load_economy_state()
	if is_new_game:
		inventory.ensure_starter_supplies()
	
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
	if auto_save_on_change: call_deferred("_save_completed_order")

func _on_hutieu_order_completed(order: BusinessOrder, reward: int) -> void:
	var tx_id := "hutieu_order_%s" % order.order_id
	var desc := "Bán hủ tiếu: %s (%s)" % [order.service_title, order.customer_name]
	wallet.deposit(reward, "hutieu_revenue", desc, tx_id)
	if auto_save_on_change: call_deferred("_save_completed_order")

func _save_completed_order() -> void:
	if is_inside_tree() and auto_save_on_change:
		save_economy_state()

func get_product(product_id: String) -> EconomyProduct:
	var normalized := InventoryManager.normalize_item_id(product_id)
	return catalog.get(normalized, catalog.get(product_id, null))

func get_house_level() -> int:
	_ensure_house_manager()
	var level := 1
	if inventory.is_upgrade_owned("upg_house_level_3"): level = 3
	elif inventory.is_upgrade_owned("upg_house_level_2"): level = 2
	if is_instance_valid(house_manager) and "progression_manager" in house_manager and is_instance_valid(house_manager.progression_manager):
		return maxi(level, house_manager.progression_manager.house_level)
	var saved_house := EconomySaveSystem.load_house_data(save_file_path)
	return maxi(level, clampi(int(saved_house.get("level", 1)), 1, 3))

func is_product_owned(product: EconomyProduct) -> bool:
	if not product or not product.is_unique: return false
	if product.category == "furniture" or product.id.begins_with("furn_"):
		return inventory.is_furniture_owned(product.id)
	if product.category == "house_upgrade":
		if inventory.is_upgrade_owned(product.id): return true
		if product.id == "upg_house_level_2": return get_house_level() >= 2
		if product.id == "upg_house_level_3": return get_house_level() >= 3
		_ensure_house_manager()
		if is_instance_valid(house_manager) and "progression_manager" in house_manager and is_instance_valid(house_manager.progression_manager):
			return house_manager.progression_manager.has_upgrade(product.id)
		var saved := EconomySaveSystem.load_house_data(save_file_path)
		var flags := {"upg_house_tile_yard": "tile_yard", "upg_house_flower_garden": "flower_garden", "upg_house_modern_kitchen": "modern_kitchen"}
		var flag: String = flags.get(product.id, "")
		var areas: Variant = saved.get("unlocked_areas", [])
		return flag != "" and (bool(saved.get("has_" + flag, false)) or (areas is Array and flag in areas))
	if product.id == "pet_cat_adoption":
		if inventory.is_upgrade_owned(product.id): return true
		if is_inside_tree():
			var pet_mgr := get_tree().get_first_node_in_group("pet_manager") as PetManager
			if is_instance_valid(pet_mgr): return pet_mgr.is_adopted
		return bool(EconomySaveSystem.load_pet_data(save_file_path).get("is_adopted", false))
	if product.category == "business_upgrade":
		return inventory.is_upgrade_owned(product.id)
	return inventory.has_item(product.id)

func purchase_prerequisite_message(product: EconomyProduct) -> String:
	if product and product.id == "upg_house_level_3" and get_house_level() < 2:
		return "Hãy nâng cấp nhà lên Cấp 2 trước!"
	return ""

func get_products_by_category(category: String) -> Array[EconomyProduct]:
	var result: Array[EconomyProduct] = []
	for prod in catalog.values():
		if prod.category == category:
			result.append(prod)
		elif category == "pet" and (prod.id.begins_with("pet_") or prod.id.begins_with("furn_pet_")):
			if not result.has(prod):
				result.append(prod)
		elif category == "food_ingredient" and (prod.category == "farming_seed" or prod.category == "produce"):
			if not result.has(prod):
				result.append(prod)
		elif category == "farming" and (prod.category == "farming_seed" or prod.category == "produce"):
			if not result.has(prod):
				result.append(prod)
	return result

func get_pet_products() -> Array[EconomyProduct]:
	return get_products_by_category("pet")

func get_farming_products() -> Array[EconomyProduct]:
	return get_products_by_category("farming")

func sell_produce(product_id: String, count: int = 1) -> Dictionary:
	var product: EconomyProduct = get_product(product_id)
	if not product or product.category != "produce" or count <= 0:
		return { "success": false, "reason": "NOT_FOUND", "message": "Không tìm thấy nông sản hợp lệ!" }

	if not inventory.has_item(product_id) or inventory.get_item_count(product_id) < count:
		return { "success": false, "reason": "INSUFFICIENT_ITEMS", "message": "Không đủ nông sản trong túi đồ để bán!" }

	var earnings := product.price * count
	inventory.remove_item(product_id, count)

	var tx_id := "sell_%s_%d_%d" % [product_id, Time.get_ticks_usec(), randi() % 1000000]
	var tx_desc := "Bán nông sản: %s x%d" % [product.name, count]
	if not wallet.deposit(earnings, "farm_revenue", tx_desc, tx_id):
		inventory.add_item(product_id, count)
		return { "success": false, "reason": "PAYMENT_FAILED", "message": "Không thể ghi nhận tiền bán nông sản." }

	if is_inside_tree() and get_tree():
		var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(daily_loop) and daily_loop.has_method("record_revenue"):
			daily_loop.record_revenue(earnings)

	if auto_save_on_change:
		save_economy_state()

	produce_sold.emit(product, count, earnings)
	return {
		"success": true,
		"product": product,
		"count": count,
		"earnings": earnings,
		"message": "Đã bán %d %s, thu về %s!" % [count, product.name, HouseholdWallet.format_money(earnings)]
	}

func purchase_product(product_id: String, count := 1) -> Dictionary:
	var product: EconomyProduct = get_product(product_id)
	if not product:
		var err := { "success": false, "reason": "NOT_FOUND", "message": "Không tìm thấy mặt hàng này!" }
		purchase_failed.emit(product_id, err["reason"], err["message"])
		return err
	
	if count <= 0:
		var err := { "success": false, "reason": "INVALID_COUNT", "message": "Số lượng phải lớn hơn không!" }
		purchase_failed.emit(product_id, err["reason"], err["message"])
		return err

	# House levels are sequential, including saves created by the board.
	if product_id == "upg_house_level_2" or product_id == "upg_house_level_3":
		var level := get_house_level()
		var target_level := 2 if product_id == "upg_house_level_2" else 3
		if level >= target_level:
			var err := { "success": false, "reason": "ALREADY_OWNED", "message": "Nhà đã đạt cấp này!" }
			purchase_failed.emit(product_id, err["reason"], err["message"])
			return err
		var prerequisite := purchase_prerequisite_message(product)
		if prerequisite != "":
			var err := { "success": false, "reason": "PREREQUISITE", "message": prerequisite }
			purchase_failed.emit(product_id, err["reason"], err["message"])
			return err

	if product.is_unique:
		count = 1
		if is_product_owned(product):
			var err := { "success": false, "reason": "ALREADY_OWNED", "message": "Bạn đã sở hữu món đồ hoặc nâng cấp này!" }
			purchase_failed.emit(product_id, err["reason"], err["message"])
			return err
	
	var total_cost := product.price * count
	if not wallet.can_afford(total_cost):
		var err := {
			"success": false,
			"reason": "INSUFFICIENT_FUNDS",
			"message": "Không đủ tiền trong ví gia đình! Cần %s (Hiện có: %s)" % [
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
	if product.category == "furniture" or product.id.begins_with("furn_"):
		inventory.unlock_furniture(product.id, count, not product.is_unique)
		_ensure_house_manager()
		if is_instance_valid(house_manager) and house_manager.has_method("sync_furniture_storage"):
			house_manager.sync_furniture_storage(inventory)
	elif product.category == "business_upgrade" or product.category == "house_upgrade":
		inventory.unlock_upgrade(product.id)
		_apply_upgrade_effect(product)
	elif product.id == "pet_cat_adoption":
		inventory.unlock_upgrade(product.id)
		var pet_mgr := get_tree().get_first_node_in_group("pet_manager")
		if is_instance_valid(pet_mgr) and pet_mgr.has_method("adopt_cat"):
			pet_mgr.adopt_cat()
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
	_ensure_house_manager()
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
		"upg_house_tile_yard":
			if is_instance_valid(house_manager):
				if "progression_manager" in house_manager and house_manager.progression_manager.has_method("apply_tile_yard_upgrade"):
					house_manager.progression_manager.apply_tile_yard_upgrade()
				if house_manager.has_method("rebuild_house"):
					house_manager.rebuild_house()
		"upg_house_flower_garden":
			if is_instance_valid(house_manager):
				if "progression_manager" in house_manager and house_manager.progression_manager.has_method("apply_flower_garden_upgrade"):
					house_manager.progression_manager.apply_flower_garden_upgrade()
				if house_manager.has_method("rebuild_house"):
					house_manager.rebuild_house()
		"upg_house_modern_kitchen":
			if is_instance_valid(house_manager):
				if "progression_manager" in house_manager and house_manager.progression_manager.has_method("apply_modern_kitchen_upgrade"):
					house_manager.progression_manager.apply_modern_kitchen_upgrade()
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
	_ensure_house_manager()
	var b_data := {}
	if is_instance_valid(garage_business):
		b_data["garage_earnings"] = garage_business.total_earnings
		b_data["garage_served"] = garage_business.customers_served
		b_data["garage_stats"] = garage_business.get_persistent_stats()
	if is_instance_valid(hutieu_business):
		b_data["hutieu_earnings"] = hutieu_business.total_earnings
		b_data["hutieu_served"] = hutieu_business.customers_served
		b_data["hutieu_stats"] = hutieu_business.get_persistent_stats()
	
	if is_inside_tree() and get_tree():
		var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(daily_loop) and "current_day" in daily_loop:
			b_data["day"] = daily_loop.current_day
			if daily_loop.has_method("get_save_data"):
				b_data["daily_state"] = daily_loop.get_save_data()
		else:
			var time_mgr = get_tree().get_first_node_in_group("time_manager")
			if is_instance_valid(time_mgr) and "current_day" in time_mgr:
				b_data["day"] = time_mgr.current_day
	
	if is_inside_tree():
		var clock := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
		if is_instance_valid(clock):
			b_data["hour"] = clock.current_hour

	if not b_data.has("daily_state") and not pending_daily_state.is_empty():
		b_data["daily_state"] = pending_daily_state

	# Preserve objective progress if its manager has not entered the tree yet.
	b_data["objectives"] = EconomySaveSystem.load_objective_data(p)
	if is_inside_tree():
		var objective_mgr = get_tree().get_first_node_in_group("daily_objective_manager")
		if is_instance_valid(objective_mgr) and objective_mgr.has_method("get_save_data"):
			b_data["objectives"] = objective_mgr.get_save_data()

	var h_data := {}
	if is_instance_valid(house_manager) and house_manager.has_method("get_save_data"):
		h_data = house_manager.get_save_data()
	else:
		h_data = EconomySaveSystem.load_house_data(p)

	var pet_data := EconomySaveSystem.load_pet_data(p)
	if is_inside_tree() and get_tree():
		var pet_mgr = get_tree().get_first_node_in_group("pet_manager")
		if is_instance_valid(pet_mgr) and pet_mgr.has_method("get_save_data"):
			pet_data = pet_mgr.get_save_data()

	var farm_data := EconomySaveSystem.load_farm_data(p)
	if is_inside_tree() and get_tree():
		var garden_mgr = get_tree().get_first_node_in_group("garden_manager")
		if is_instance_valid(garden_mgr) and garden_mgr.has_method("get_save_data"):
			farm_data = garden_mgr.get_save_data()
	
	var saved := EconomySaveSystem.save_economy(wallet, inventory, b_data, h_data, p, pet_data, farm_data)
	if not saved and not _save_failure_reported:
		_save_failure_reported = true
		save_failed.emit(p)
		if is_inside_tree():
			var fx = get_tree().get_first_node_in_group("chaos_feedback")
			if is_instance_valid(fx) and fx.has_method("show_toast"):
				fx.show_toast("⚠️ Không thể lưu tiến trình. Hãy kiểm tra tệp lưu và dung lượng.")
	elif saved:
		_save_failure_reported = false
	return saved

func load_economy_state(path := "") -> bool:
	var p := path if path != "" else save_file_path
	var b_data := EconomySaveSystem.load_economy(wallet, inventory, p)
	# A usable save always supplies a day, including legacy saves. An empty
	# result means no primary or backup could be loaded; leave live state alone.
	if b_data.is_empty():
		return false
	
	if b_data.get("daily_state", null) is Dictionary:
		pending_daily_state = b_data["daily_state"]
	else:
		pending_daily_state = {}
	if is_instance_valid(garage_business) and b_data.get("garage_stats", null) is Dictionary:
		garage_business.apply_persistent_stats(b_data["garage_stats"])
	if is_instance_valid(hutieu_business) and b_data.get("hutieu_stats", null) is Dictionary:
		hutieu_business.apply_persistent_stats(b_data["hutieu_stats"])

	if is_instance_valid(garage_business) and b_data.has("garage_earnings"):
		garage_business.total_earnings = int(b_data["garage_earnings"])
		garage_business.customers_served = int(b_data.get("garage_served", 0))
		if not b_data.has("garage_stats"):
			garage_business.business_level = clampi(1 + int(garage_business.customers_served / 4), 1, 5)
	if is_instance_valid(hutieu_business) and b_data.has("hutieu_earnings"):
		hutieu_business.total_earnings = int(b_data["hutieu_earnings"])
		hutieu_business.customers_served = int(b_data.get("hutieu_served", 0))
		if not b_data.has("hutieu_stats"):
			hutieu_business.business_level = clampi(1 + int(hutieu_business.customers_served / 4), 1, 5)
	
	if b_data.has("day") and is_inside_tree() and get_tree():
		var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(daily_loop) and daily_loop.has_method("set_day"):
			daily_loop.set_day(int(b_data["day"]))
			if daily_loop.has_method("apply_save_data"):
				daily_loop.apply_save_data(pending_daily_state)
		var time_mgr = get_tree().get_first_node_in_group("time_manager")
		if is_instance_valid(time_mgr) and "current_day" in time_mgr:
			time_mgr.current_day = int(b_data["day"])
			if b_data.has("hour"):
				# Restoring the clock is not an elapsed hour of crop growth.
				time_mgr.set_hour(float(b_data["hour"]))
	
	_ensure_house_manager()
	if is_instance_valid(house_manager) and b_data.has("house") and house_manager.has_method("apply_save_data"):
		house_manager.apply_save_data(b_data["house"])
		
	# Restore Pet Data (Requirement 7)
	if b_data.has("day") and is_inside_tree() and get_tree():
		var pet_mgr = get_tree().get_first_node_in_group("pet_manager")
		if is_instance_valid(pet_mgr) and pet_mgr.has_method("apply_save_data"):
			pet_mgr.apply_save_data(b_data.get("pet", {}))

	# Restore Farm Data (Requirement 7)
	if b_data.has("day") and is_inside_tree() and get_tree():
		var garden_mgr = get_tree().get_first_node_in_group("garden_manager")
		if is_instance_valid(garden_mgr) and garden_mgr.has_method("apply_save_data"):
			var farm_data: Dictionary = b_data.get("farm", {})
			garden_mgr.apply_save_data(farm_data if farm_data.has("plots") else {"plots": []})

	apply_all_owned_upgrades()
	
	return true
