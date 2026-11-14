class_name FarmSystem
extends RefCounted
## Manages all farm plots and coordinates planting, growth updates, and harvesting.

signal plot_changed(plot_id: int)

var plots: Array[FarmPlot] = []

func _init(total_plots: int = 6, initial_unlocked: int = 4) -> void:
	reset_plots(total_plots, initial_unlocked)

func reset_plots(total_plots: int = 6, initial_unlocked: int = 4) -> void:
	plots.clear()
	for i in range(total_plots):
		var st := FarmPlot.State.EMPTY if i < initial_unlocked else FarmPlot.State.LOCKED
		plots.append(FarmPlot.new(i, st))

func get_plot(plot_id: int) -> FarmPlot:
	if plot_id < 0 or plot_id >= plots.size():
		return null
	return plots[plot_id]

func plant_plot(plot_id: int, crop_cfg: Dictionary, wallet: Wallet, clock: GameClock) -> Dictionary:
	var plot := get_plot(plot_id)
	if plot == null:
		return {"ok": false, "reason": "Ô đất không tồn tại."}
	if plot.state == FarmPlot.State.LOCKED:
		return {"ok": false, "reason": "Ô đất đang bị khóa."}
	if plot.state != FarmPlot.State.EMPTY:
		return {"ok": false, "reason": "Ô đất đang có cây."}

	var cost := int(crop_cfg.get("seed_cost", 5))
	if not wallet.can_afford(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}

	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không thể trừ xu."}

	var crop_id := String(crop_cfg.get("id", "carrot"))
	var duration := int(crop_cfg.get("grow_duration_sec", 300))
	plot.plant(crop_id, clock.now(), duration)
	plot_changed.emit(plot_id)
	return {"ok": true, "cost": cost, "crop_id": crop_id}

func harvest_plot(plot_id: int, crop_cfg: Dictionary, inventory: Inventory) -> Dictionary:
	var plot := get_plot(plot_id)
	if plot == null:
		return {"ok": false, "reason": "Ô đất không tồn tại."}
	if plot.state != FarmPlot.State.READY:
		return {"ok": false, "reason": "Cây chưa chín để thu hoạch."}

	var harvested_crop := plot.crop_id if plot.crop_id != "" else String(crop_cfg.get("id", "carrot"))
	var yield_count := int(crop_cfg.get("harvest_yield", 2))
	if not plot.harvest():
		return {"ok": false, "reason": "Thu hoạch thất bại."}

	inventory.add_item(harvested_crop, yield_count)
	plot_changed.emit(plot_id)
	return {"ok": true, "crop_id": harvested_crop, "yield": yield_count}

func tick(clock: GameClock) -> int:
	var now_unix := clock.now()
	var matured := 0
	for plot in plots:
		if plot.update_growth(now_unix):
			matured += 1
			plot_changed.emit(plot.id)
	return matured

func get_first_locked_plot_id() -> int:
	for plot in plots:
		if plot.state == FarmPlot.State.LOCKED:
			return plot.id
	return -1

func get_locked_count() -> int:
	var count := 0
	for plot in plots:
		if plot.state == FarmPlot.State.LOCKED:
			count += 1
	return count
