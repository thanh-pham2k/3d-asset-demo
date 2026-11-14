class_name OrderBoard
extends RefCounted
## Handles VERY MVP order fulfillment (4 carrots -> +60 xu).

signal order_completed(reward_coins: int)

var order_id: String = "order_carrot_4"
var title: String = "Đơn hàng Cà rốt tươi"
var item_id: String = "carrot"
var required_count: int = 4
var reward_coins: int = 60

func _init(order_cfg: Dictionary = {}) -> void:
	if not order_cfg.is_empty():
		apply_config(order_cfg)

func apply_config(order_cfg: Dictionary) -> void:
	order_id = String(order_cfg.get("id", "order_carrot_4"))
	title = String(order_cfg.get("title", "Đơn hàng Cà rốt tươi"))
	item_id = String(order_cfg.get("item_id", "carrot"))
	required_count = int(order_cfg.get("required_count", 4))
	reward_coins = int(order_cfg.get("reward_coins", 60))

func can_deliver(inventory: Inventory) -> bool:
	return inventory.has_item(item_id, required_count)

func deliver(inventory: Inventory, wallet: Wallet) -> Dictionary:
	if not can_deliver(inventory):
		return {
			"ok": false,
			"reason": "Cần %d %s (hiện có %d)." % [required_count, item_id, inventory.get_count(item_id)]
		}
	if not inventory.remove_item(item_id, required_count):
		return {"ok": false, "reason": "Không thể trừ nông sản trong kho."}
	wallet.earn(reward_coins)
	order_completed.emit(reward_coins)
	return {"ok": true, "reward": reward_coins, "delivered": required_count}
