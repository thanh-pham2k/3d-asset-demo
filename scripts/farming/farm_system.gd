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

	var cost := maxi(0, int(crop_cfg.get("seed_cost", 5)))
	if not wallet.can_afford(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}

	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không thể trừ xu."}

	var crop_id := String(crop_cfg.get("id", "carrot"))
	var duration := maxi(1, int(crop_cfg.get("grow_duration_sec", 300)))
	if not plot.plant(crop_id, clock.now(), duration):
		wallet.earn(cost)
		return {"ok": false, "reason": "Không thể trồng trên ô đất này."}
	plot_changed.emit(plot_id)
	return {"ok": true, "cost": cost, "crop_id": crop_id}

func harvest_plot(plot_id: int, crop_cfg: Dictionary, inventory: Inventory) -> Dictionary:
	var plot := get_plot(plot_id)
	if plot == null:
		return {"ok": false, "reason": "Ô đất không tồn tại."}
	if plot.state != FarmPlot.State.READY:
		return {"ok": false, "reason": "Cây chưa chín để thu hoạch."}

	var harvested_crop := plot.crop_id if plot.crop_id != "" else String(crop_cfg.get("id", "carrot"))
	var yield_count := maxi(1, int(crop_cfg.get("harvest_yield", 2)))
	if not inventory.can_add(yield_count):
		return {
			"ok": false,
			"reason": "Kho đầy (%d/%d)! Cần trống %d chỗ để thu hoạch." % [
				inventory.get_total_count(),
				inventory.capacity,
				yield_count
			]
		}
	if not plot.harvest():
		return {"ok": false, "reason": "Thu hoạch thất bại."}

	if not inventory.add_item(harvested_crop, yield_count):
		return {"ok": false, "reason": "Không thể thêm vào kho."}
	plot_changed.emit(plot_id)
	return {"ok": true, "crop_id": harvested_crop, "yield": yield_count}

func plant_all_empty(crop_cfg: Dictionary, wallet: Wallet, clock: GameClock) -> Dictionary:
	var planted := 0
	var total_cost := 0
	var last_reason := ""
	for plot in plots:
		if plot.state != FarmPlot.State.EMPTY:
			continue
		var res := plant_plot(plot.id, crop_cfg, wallet, clock)
		if bool(res.get("ok", false)):
			planted += 1
			total_cost += int(res.get("cost", 0))
		else:
			last_reason = String(res.get("reason", ""))
			break
	return {
		"ok": planted > 0,
		"planted": planted,
		"cost": total_cost,
		"reason": last_reason
	}

func harvest_all_ready(crops_by_id: Dictionary, inventory: Inventory) -> Dictionary:
	var harvested := 0
	var gained: Dictionary = {}
	var stopped_full := false
	var last_reason := ""
	for plot in plots:
		if plot.state != FarmPlot.State.READY:
			continue
		var cid := plot.crop_id if plot.crop_id != "" else "carrot"
		var cfg: Dictionary = crops_by_id.get(cid, {"id": cid, "harvest_yield": 2})
		var res := harvest_plot(plot.id, cfg, inventory)
		if bool(res.get("ok", false)):
			harvested += 1
			var y := int(res.get("yield", 1))
			gained[cid] = int(gained.get(cid, 0)) + y
		else:
			stopped_full = true
			last_reason = String(res.get("reason", "Kho đầy."))
			break
	return {
		"ok": harvested > 0,
		"harvested": harvested,
		"gained": gained,
		"stopped_full": stopped_full,
		"reason": last_reason
	}

func has_active_crops() -> bool:
	for plot in plots:
		if plot.state == FarmPlot.State.GROWING or plot.state == FarmPlot.State.READY:
			return true
	return false

func rebase_growing_timers(old_now_unix: int, new_now_unix: int) -> void:
	for plot in plots:
		if plot.state != FarmPlot.State.GROWING:
			continue
		var elapsed := plot.timer.get_elapsed_seconds(old_now_unix)
		plot.timer.planted_at_unix = new_now_unix - elapsed
		plot_changed.emit(plot.id)

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
