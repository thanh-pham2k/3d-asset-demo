class_name FarmUpgrade
extends RefCounted
## Handles unlocking locked farm plots for coins.

signal plot_unlocked(plot_id: int)

var unlock_cost: int = 120

func _init(upgrade_cfg: Dictionary = {}) -> void:
	if not upgrade_cfg.is_empty():
		unlock_cost = int(upgrade_cfg.get("unlock_plot_cost", 120))

func can_unlock(farm: FarmSystem, wallet: Wallet) -> bool:
	return farm.get_first_locked_plot_id() != -1 and wallet.can_afford(unlock_cost)

func unlock_next_plot(farm: FarmSystem, wallet: Wallet) -> Dictionary:
	var target_id := farm.get_first_locked_plot_id()
	if target_id == -1:
		return {"ok": false, "reason": "Tất cả ô đất đã được mở khóa."}
	return unlock_specific_plot(target_id, farm, wallet)

func unlock_specific_plot(plot_id: int, farm: FarmSystem, wallet: Wallet) -> Dictionary:
	var plot := farm.get_plot(plot_id)
	if plot == null:
		return {"ok": false, "reason": "Ô đất không tồn tại."}
	if plot.state != FarmPlot.State.LOCKED:
		return {"ok": false, "reason": "Ô đất này đã mở khóa rồi."}
	if not wallet.can_afford(unlock_cost):
		return {"ok": false, "reason": "Không đủ xu để mở ô đất (cần %d xu)." % unlock_cost}
	if not wallet.spend(unlock_cost):
		return {"ok": false, "reason": "Không thể trừ xu."}
	plot.unlock()
	farm.plot_changed.emit(plot_id)
	plot_unlocked.emit(plot_id)
	return {"ok": true, "plot_id": plot_id, "cost": unlock_cost}
