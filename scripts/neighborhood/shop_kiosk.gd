class_name ShopKiosk
extends Interactable

## Interactive shopping kiosk placed in neighborhood stores (Furniture Store,
## Wet Market, Garage Supplier, House Renovation Board).
## Allows the player to browse items, check prices against the shared wallet,
## and purchase goods directly using existing player controls.

@export var kiosk_title: String = "Cửa hàng"
@export var product_category: String = "furniture" # "furniture", "food_ingredient", "repair_tool", "house_upgrade", "business_upgrade"
@export var target_system: String = "" # "garage", "hutieu", "house", ""

var economy_mgr: EconomyManager
var available_products: Array[EconomyProduct] = []
var selected_index: int = 0
var info_label: Label3D

func _ready() -> void:
	kind = "shop_kiosk"
	add_to_group("interactables")
	
	info_label = Label3D.new()
	info_label.position = Vector3(0, 1.8, 0)
	info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	info_label.font_size = 22
	info_label.pixel_size = 0.004
	info_label.outline_size = 6
	info_label.modulate = Color("b2ebf2")
	info_label.outline_modulate = Color("1a1a1a")
	info_label.visible = false
	add_child(info_label)
	
	call_deferred("_setup_catalog")

func _setup_catalog() -> void:
	economy_mgr = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(economy_mgr):
		var prods := economy_mgr.get_products_by_category(product_category)
		if target_system != "":
			available_products.clear()
			for p in prods:
				if p.target_system == target_system:
					available_products.append(p)
		else:
			available_products = prods

func available(player_node: Node3D) -> bool:
	return enabled and (user == null or user == player_node)

func prompt(_player: Node3D) -> String:
	if available_products.is_empty():
		_setup_catalog()
	var wallet_str := ""
	if is_instance_valid(economy_mgr):
		wallet_str = " (Ví: %s)" % HouseholdWallet.format_money(economy_mgr.wallet.balance)
	if available_products.is_empty():
		return "Mua sắm tại %s%s" % [kiosk_title, wallet_str]
	var prod: EconomyProduct = available_products[selected_index % available_products.size()]
	var status_str := ""
	if is_instance_valid(economy_mgr):
		if (prod.category == "business_upgrade" or prod.category == "house_upgrade") and economy_mgr.inventory.is_upgrade_owned(prod.id):
			status_str = " [ĐÃ SỞ HỮU]"
		elif prod.category == "furniture" and prod.is_unique and economy_mgr.inventory.is_furniture_owned(prod.id):
			status_str = " [ĐÃ SỞ HỮU]"
	return "Mua sắm %s: %s%s%s" % [prod.name, HouseholdWallet.format_money(prod.price), status_str, wallet_str]

func interact(player_node: Node3D) -> void:
	if not is_instance_valid(economy_mgr):
		economy_mgr = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if not is_instance_valid(economy_mgr): return
	
	if available_products.is_empty():
		available_products = economy_mgr.get_products_by_category(product_category)
	if available_products.is_empty():
		_show_feedback("Cửa hàng hiện chưa có sản phẩm!", Color("cfd8dc"))
		return
	
	var product: EconomyProduct = available_products[selected_index % available_products.size()]
	
	var player_id := 1
	if is_instance_valid(player_node) and "player_id" in player_node:
		player_id = player_node.player_id
	
	var dual_mgr := get_tree().get_first_node_in_group("dual_confirmation_manager") as DualConfirmationManager
	if is_instance_valid(dual_mgr) and dual_mgr.is_coop_active and product.base_price >= 50000:
		var executed := dual_mgr.request_purchase(
			player_id,
			product.title,
			product.base_price,
			Callable(self, "_execute_purchase").bind(product)
		)
		if not executed:
			_show_feedback("⏳ Chờ người chơi P%d xác nhận mua '%s'!" % [2 if player_id == 1 else 1, product.title], Color("fff59d"))
			return

	_execute_purchase(product)

func _execute_purchase(product: EconomyProduct) -> void:
	if not is_instance_valid(economy_mgr): return
	var result: Dictionary = economy_mgr.purchase_product(product.id, 1)
	if result["success"]:
		_show_feedback("✅ %s (-%s)" % [
			result["message"],
			HouseholdWallet.format_money(result["total_cost"])
		], Color("69f0ae"))
		selected_index = (selected_index + 1) % available_products.size()
	else:
		_show_feedback("⚠️ %s" % result["message"], Color("ff5252"))
		if result["reason"] == "ALREADY_OWNED":
			selected_index = (selected_index + 1) % available_products.size()

func _show_feedback(text: String, color: Color) -> void:
	info_label.text = text
	info_label.modulate = color
	info_label.visible = true
	
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(info_label, "visible", false, 0.0)
