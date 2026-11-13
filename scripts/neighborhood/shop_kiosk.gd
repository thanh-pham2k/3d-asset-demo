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
var pending_coop_product: EconomyProduct = null

func _ready() -> void:
	kind = "shop_kiosk"
	interaction_radius = 2.0
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

	_connect_dual_manager()

func _connect_dual_manager() -> void:
	var dual_mgr := get_tree().get_first_node_in_group("dual_confirmation_manager") as DualConfirmationManager
	if is_instance_valid(dual_mgr):
		if not dual_mgr.confirmation_approved.is_connected(_on_coop_approved):
			dual_mgr.confirmation_approved.connect(_on_coop_approved)
		if not dual_mgr.confirmation_declined.is_connected(_on_coop_declined):
			dual_mgr.confirmation_declined.connect(_on_coop_declined)

func _on_coop_approved(_initiator_id: int, _product_name: String, _cost: int) -> void:
	pending_coop_product = null

func _on_coop_declined(initiator_id: int, product_name: String, reason: String) -> void:
	if pending_coop_product == null or pending_coop_product.name != product_name:
		return
	pending_coop_product = null

	match reason:
		"DECLINED_BY_PARTNER":
			var other_id := 2 if initiator_id == 1 else 1
			_show_feedback("❌ P%d đã từ chối mua '%s'!" % [other_id, product_name], Color("ff5252"))
		"TIMEOUT":
			_show_feedback("⌛ Hết thời gian chờ xác nhận mua '%s'!" % product_name, Color("ffb74d"))
		"INSUFFICIENT_FUNDS":
			_show_feedback("⚠️ Không đủ tiền trong ví gia đình!", Color("ff5252"))
		_:
			_show_feedback("⚠️ Yêu cầu mua '%s' đã bị hủy!" % product_name, Color("ff5252"))

func available(player_node: Node3D) -> bool:
	return enabled and (user == null or user == player_node)

func is_product_owned(prod: EconomyProduct) -> bool:
	return is_instance_valid(economy_mgr) and economy_mgr.is_product_owned(prod)

func _get_held_produce_count() -> int:
	if not is_instance_valid(economy_mgr):
		economy_mgr = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if not is_instance_valid(economy_mgr):
		return 0
	var count := 0
	for pid in ["produce_lettuce", "produce_tomato", "produce_carrot"]:
		count += economy_mgr.inventory.get_item_count(pid)
	return count

func prompt(_player: Node3D) -> String:
	if available_products.is_empty():
		_setup_catalog()
	var wallet_str := ""
	if is_instance_valid(economy_mgr):
		wallet_str = " (Ví: %s)" % HouseholdWallet.format_money(economy_mgr.wallet.balance)
	var base_str := "Mua sắm tại %s%s" % [kiosk_title, wallet_str]
	return base_str

func interact(player_node: Node3D) -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(economy_mgr):
		economy_mgr = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	
	var shop_ui := ShoppingUI.get_or_create(get_tree())
	if is_instance_valid(shop_ui):
		shop_ui.open_shop(kiosk_title, product_category, target_system, self, player_node)

func _execute_purchase(product: EconomyProduct) -> void:
	pending_coop_product = null
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
