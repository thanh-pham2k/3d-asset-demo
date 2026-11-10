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
	var tx_id := "buy_%s_%d" % [product_id, Time.get_ticks_msec()]
	var tx_desc := "Mua: %s x%d" % [product.name, count]
	var ok := wallet.withdraw(total_cost, product.category, tx_desc, tx_id)
	if not ok:
		var err := { "success": false, "reason": "PAYMENT_FAILED", "message": "Giao dịch không thành công!" }
		purchase_failed.emit(product_id, err["reason"], err["message"])
		return err
	
	# Add to inventory / unlock ownership
	if product.category == "furniture":
		inventory.unlock_furniture(product.id)
	elif product.category == "business_upgrade" or product.category == "house_upgrade":
		inventory.unlock_upgrade(product.id)
		_apply_upgrade_effect(product)
	else:
		# Consumable item
		inventory.add_item(product.id, count)
	
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
	match product.id:
		"upg_garage_second_bay":
			if is_instance_valid(garage_business):
				garage_business.spawn_interval = 10.0 # Faster customer flow
		"upg_hutieu_extra_table":
			if is_instance_valid(hutieu_business):
				hutieu_business.spawn_interval = 10.0
		"upg_hutieu_quick_stove":
			if is_instance_valid(hutieu_business):
				# Boost cooking efficiency
				pass

func save_economy_state(path := "") -> bool:
	var p := path if path != "" else save_file_path
	var b_data := {}
	if is_instance_valid(garage_business):
		b_data["garage_earnings"] = garage_business.total_earnings
		b_data["garage_served"] = garage_business.customers_served
	if is_instance_valid(hutieu_business):
		b_data["hutieu_earnings"] = hutieu_business.total_earnings
		b_data["hutieu_served"] = hutieu_business.customers_served
	
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
	if is_instance_valid(house_manager) and b_data.has("house") and house_manager.has_method("apply_save_data"):
		house_manager.apply_save_data(b_data["house"])
	
	return true
