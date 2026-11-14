class_name GoalsSystem
extends RefCounted
## Manages optional daily objectives, multi-system weekly goals, long-term milestones, and unified collections.

signal goals_changed()

var daily_cfg: Array[Dictionary] = []
var weekly_cfg: Array[Dictionary] = []
var milestones_cfg: Array[Dictionary] = []

# Daily state (optional, no streak penalties)
var daily_metrics: Dictionary = {
	"harvests": 0,
	"orders_or_deliveries": 0,
	"cozy_actions": 0
}
var claimed_daily: Dictionary = {}

# Weekly state
var weekly_metrics: Dictionary = {
	"dishes_served": 0,
	"crafted_items": 0,
	"deliveries_done": 0,
	"orders_done": 0,
	"npc_helps": 0,
	"cozy_actions": 0
}
var claimed_weekly: Dictionary = {}

# Long-term state
var total_harvests: int = 0
var total_dishes: int = 0
var total_crafted: int = 0
var total_deliveries: int = 0
var total_orders: int = 0
var total_npc_helps: int = 0
var claimed_milestones: Dictionary = {}

# Discovered collections
var discovered_crops: Dictionary = {}
var discovered_recipes: Dictionary = {}
var discovered_dishes: Dictionary = {}

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)
	reset()

func apply_config(cfg: Dictionary) -> void:
	daily_cfg.clear()
	for entry in (cfg.get("daily_objectives", []) as Array):
		if typeof(entry) == TYPE_DICTIONARY:
			daily_cfg.append((entry as Dictionary).duplicate(true))

	weekly_cfg.clear()
	for entry in (cfg.get("weekly_goals", []) as Array):
		if typeof(entry) == TYPE_DICTIONARY:
			weekly_cfg.append((entry as Dictionary).duplicate(true))

	milestones_cfg.clear()
	for entry in (cfg.get("long_term_milestones", []) as Array):
		if typeof(entry) == TYPE_DICTIONARY:
			milestones_cfg.append((entry as Dictionary).duplicate(true))

func reset() -> void:
	daily_metrics = {"harvests": 0, "orders_or_deliveries": 0, "cozy_actions": 0}
	claimed_daily.clear()
	weekly_metrics = {
		"dishes_served": 0, "crafted_items": 0,
		"deliveries_done": 0, "orders_done": 0,
		"npc_helps": 0, "cozy_actions": 0
	}
	claimed_weekly.clear()
	total_harvests = 0
	total_dishes = 0
	total_crafted = 0
	total_deliveries = 0
	total_orders = 0
	total_npc_helps = 0
	claimed_milestones.clear()
	discovered_crops.clear()
	discovered_recipes.clear()
	discovered_dishes.clear()
	goals_changed.emit()

func record_harvest(crop_id: String, count: int = 1) -> void:
	var n := maxi(1, count)
	daily_metrics["harvests"] = int(daily_metrics.get("harvests", 0)) + n
	total_harvests += n
	if crop_id != "":
		discovered_crops[crop_id] = true
	goals_changed.emit()

func record_craft(recipe_id: String, count: int = 1) -> void:
	var n := maxi(1, count)
	weekly_metrics["crafted_items"] = int(weekly_metrics.get("crafted_items", 0)) + n
	total_crafted += n
	if recipe_id != "":
		discovered_recipes[recipe_id] = true
	goals_changed.emit()

func record_order(count: int = 1) -> void:
	var n := maxi(1, count)
	daily_metrics["orders_or_deliveries"] = int(daily_metrics.get("orders_or_deliveries", 0)) + n
	weekly_metrics["orders_done"] = int(weekly_metrics.get("orders_done", 0)) + n
	total_orders += n
	goals_changed.emit()

func record_dish_served(dish_id: String, count: int = 1) -> void:
	var n := maxi(1, count)
	weekly_metrics["dishes_served"] = int(weekly_metrics.get("dishes_served", 0)) + n
	total_dishes += n
	if dish_id != "":
		discovered_dishes[dish_id] = true
	goals_changed.emit()

func record_delivery(count: int = 1) -> void:
	var n := maxi(1, count)
	daily_metrics["orders_or_deliveries"] = int(daily_metrics.get("orders_or_deliveries", 0)) + n
	weekly_metrics["deliveries_done"] = int(weekly_metrics.get("deliveries_done", 0)) + n
	total_deliveries += n
	goals_changed.emit()

func record_npc_help(count: int = 1) -> void:
	var n := maxi(1, count)
	weekly_metrics["npc_helps"] = int(weekly_metrics.get("npc_helps", 0)) + n
	total_npc_helps += n
	goals_changed.emit()

func record_cozy_action(count: int = 1) -> void:
	var n := maxi(1, count)
	daily_metrics["cozy_actions"] = int(daily_metrics.get("cozy_actions", 0)) + n
	weekly_metrics["cozy_actions"] = int(weekly_metrics.get("cozy_actions", 0)) + n
	goals_changed.emit()

func refresh_daily_optional() -> void:
	daily_metrics = {"harvests": 0, "orders_or_deliveries": 0, "cozy_actions": 0}
	claimed_daily.clear()
	goals_changed.emit()

func get_daily_progress(obj: Dictionary) -> int:
	var m := String(obj.get("metric", ""))
	return int(daily_metrics.get(m, 0))

func can_claim_daily(oid: String) -> bool:
	if claimed_daily.has(oid):
		return false
	for obj in daily_cfg:
		if String(obj.get("id", "")) == oid:
			return get_daily_progress(obj) >= int(obj.get("target", 1))
	return false

func claim_daily(oid: String, wallet: Wallet, progression: ProgressionSystem) -> Dictionary:
	if claimed_daily.has(oid):
		return {"ok": false, "reason": "Mục tiêu ngày này đã nhận thưởng rồi."}
	for obj in daily_cfg:
		if String(obj.get("id", "")) == oid:
			var target := int(obj.get("target", 1))
			if get_daily_progress(obj) < target:
				return {"ok": false, "reason": "Chưa đạt tiến độ mục tiêu."}
			claimed_daily[oid] = true
			var coins := maxi(0, int(obj.get("reward_coins", 0)))
			var xp := maxi(0, int(obj.get("reward_xp", 0)))
			if coins > 0 and wallet != null:
				wallet.earn(coins)
			var lv_res := {}
			if xp > 0 and progression != null:
				lv_res = progression.add_xp(xp)
			goals_changed.emit()
			return {
				"ok": true, "coins": coins, "xp": xp,
				"leveled_up": bool(lv_res.get("leveled_up", false)),
				"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
			}
	return {"ok": false, "reason": "Không tìm thấy mục tiêu."}

func can_claim_weekly(wid: String) -> bool:
	if claimed_weekly.has(wid):
		return false
	for w in weekly_cfg:
		if String(w.get("id", "")) == wid:
			var reqs := w.get("requirements", {}) as Dictionary
			for k: String in reqs.keys():
				if int(weekly_metrics.get(k, 0)) < int(reqs[k]):
					return false
			return true
	return false

func claim_weekly(wid: String, wallet: Wallet, progression: ProgressionSystem) -> Dictionary:
	if claimed_weekly.has(wid):
		return {"ok": false, "reason": "Mục tiêu tuần này đã nhận thưởng rồi."}
	for w in weekly_cfg:
		if String(w.get("id", "")) == wid:
			var reqs := w.get("requirements", {}) as Dictionary
			for k: String in reqs.keys():
				if int(weekly_metrics.get(k, 0)) < int(reqs[k]):
					return {"ok": false, "reason": "Chưa hoàn thành đủ yêu cầu tuần."}
			claimed_weekly[wid] = true
			var coins := maxi(0, int(w.get("reward_coins", 0)))
			var xp := maxi(0, int(w.get("reward_xp", 0)))
			if coins > 0 and wallet != null:
				wallet.earn(coins)
			var lv_res := {}
			if xp > 0 and progression != null:
				lv_res = progression.add_xp(xp)
			goals_changed.emit()
			return {
				"ok": true, "coins": coins, "xp": xp,
				"leveled_up": bool(lv_res.get("leveled_up", false)),
				"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
			}
	return {"ok": false, "reason": "Không tìm thấy mục tiêu tuần."}

func get_milestone_progress(m: Dictionary, collection_score: int) -> int:
	var metric := String(m.get("metric", ""))
	if metric == "total_harvests":
		return total_harvests
	if metric == "total_dishes":
		return total_dishes
	if metric == "collection_score":
		return collection_score
	return 0

func can_claim_milestone(mid: String, collection_score: int) -> bool:
	if claimed_milestones.has(mid):
		return false
	for m in milestones_cfg:
		if String(m.get("id", "")) == mid:
			return get_milestone_progress(m, collection_score) >= int(m.get("target", 1))
	return false

func claim_milestone(mid: String, collection_score: int, wallet: Wallet, progression: ProgressionSystem, home: HomeSystem = null) -> Dictionary:
	if claimed_milestones.has(mid):
		return {"ok": false, "reason": "Cột mốc dài hạn này đã nhận thưởng rồi."}
	for m in milestones_cfg:
		if String(m.get("id", "")) == mid:
			if get_milestone_progress(m, collection_score) < int(m.get("target", 1)):
				return {"ok": false, "reason": "Chưa đạt điều kiện cột mốc."}
			claimed_milestones[mid] = true
			var coins := maxi(0, int(m.get("reward_coins", 0)))
			var xp := maxi(0, int(m.get("reward_xp", 0)))
			if coins > 0 and wallet != null:
				wallet.earn(coins)
			var lv_res := {}
			if xp > 0 and progression != null:
				lv_res = progression.add_xp(xp)
			var spec_granted := ""
			var spec := m.get("special_reward", {}) as Dictionary
			if not spec.is_empty() and String(spec.get("type", "")) == "home_furniture" and home != null:
				var sid := String(spec.get("id", ""))
				if home.items_by_id.has(sid):
					if not home.owned_furniture.has(sid):
						home.owned_furniture[sid] = true
						spec_granted = String(spec.get("display_name", sid))
					elif wallet != null:
						wallet.earn(25)
						spec_granted = String(spec.get("display_name", sid)) + " (đã có → +25 xu)"
			goals_changed.emit()
			return {
				"ok": true, "coins": coins, "xp": xp,
				"special": spec_granted,
				"leveled_up": bool(lv_res.get("leveled_up", false)),
				"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
			}
	return {"ok": false, "reason": "Không tìm thấy cột mốc."}

func get_collection_score(home: HomeSystem, pets: PetSystem, neighborhood: NeighborhoodSystem) -> int:
	var score := discovered_crops.size() + discovered_recipes.size() + discovered_dishes.size()
	if home != null:
		score += home.owned_furniture.size()
	if pets != null:
		score += pets.owned_items.size()
	if neighborhood != null:
		score += neighborhood.built_areas.size() + neighborhood.claimed_stories.size()
	return score

func get_next_recommendation(collection_score: int) -> String:
	for obj in daily_cfg:
		var oid := String(obj.get("id", ""))
		if can_claim_daily(oid):
			return "🎁 Mục tiêu ngày '%s' đã xong — hãy nhấn Nhận thưởng!" % String(obj.get("display_name", oid))
	for w in weekly_cfg:
		var wid := String(w.get("id", ""))
		if can_claim_weekly(wid):
			return "🏆 Mục tiêu tuần '%s' đã xong — hãy nhấn Nhận thưởng!" % String(w.get("display_name", wid))
	for m in milestones_cfg:
		var mid := String(m.get("id", ""))
		if can_claim_milestone(mid, collection_score):
			return "🌟 Cột mốc '%s' đã đạt — hãy nhấn Nhận thưởng!" % String(m.get("display_name", mid))
	for obj in daily_cfg:
		var oid := String(obj.get("id", ""))
		if not claimed_daily.has(oid):
			return "💡 Gợi ý tiếp theo: %s (%d/%d)." % [String(obj.get("display_name", oid)), get_daily_progress(obj), int(obj.get("target", 1))]
	return "✨ Tất cả mục tiêu ngày đã xong! Bạn có thể làm mới mục tiêu ngày hoặc tiếp tục sưu tập."

func to_dict() -> Dictionary:
	var c_crops: Array[String] = []
	for k: String in discovered_crops.keys(): c_crops.append(k)
	var c_rec: Array[String] = []
	for k: String in discovered_recipes.keys(): c_rec.append(k)
	var c_dish: Array[String] = []
	for k: String in discovered_dishes.keys(): c_dish.append(k)
	var cd: Array[String] = []
	for k: String in claimed_daily.keys(): cd.append(k)
	var cw: Array[String] = []
	for k: String in claimed_weekly.keys(): cw.append(k)
	var cm: Array[String] = []
	for k: String in claimed_milestones.keys(): cm.append(k)
	return {
		"daily_metrics": daily_metrics.duplicate(true),
		"claimed_daily": cd,
		"weekly_metrics": weekly_metrics.duplicate(true),
		"claimed_weekly": cw,
		"total_harvests": total_harvests,
		"total_dishes": total_dishes,
		"total_crafted": total_crafted,
		"total_deliveries": total_deliveries,
		"total_orders": total_orders,
		"total_npc_helps": total_npc_helps,
		"claimed_milestones": cm,
		"discovered_crops": c_crops,
		"discovered_recipes": c_rec,
		"discovered_dishes": c_dish
	}

func load_from_dict(data: Dictionary) -> void:
	reset()
	var dm: Variant = data.get("daily_metrics", {})
	if typeof(dm) == TYPE_DICTIONARY:
		for k: String in (dm as Dictionary).keys():
			daily_metrics[k] = maxi(0, int((dm as Dictionary)[k]))
	for v in (data.get("claimed_daily", []) as Array):
		claimed_daily[String(v)] = true

	var wm: Variant = data.get("weekly_metrics", {})
	if typeof(wm) == TYPE_DICTIONARY:
		for k: String in (wm as Dictionary).keys():
			weekly_metrics[k] = maxi(0, int((wm as Dictionary)[k]))
	for v in (data.get("claimed_weekly", []) as Array):
		claimed_weekly[String(v)] = true

	total_harvests = maxi(0, int(data.get("total_harvests", 0)))
	total_dishes = maxi(0, int(data.get("total_dishes", 0)))
	total_crafted = maxi(0, int(data.get("total_crafted", 0)))
	total_deliveries = maxi(0, int(data.get("total_deliveries", 0)))
	total_orders = maxi(0, int(data.get("total_orders", 0)))
	total_npc_helps = maxi(0, int(data.get("total_npc_helps", 0)))
	for v in (data.get("claimed_milestones", []) as Array):
		claimed_milestones[String(v)] = true
	for v in (data.get("discovered_crops", []) as Array):
		discovered_crops[String(v)] = true
	for v in (data.get("discovered_recipes", []) as Array):
		discovered_recipes[String(v)] = true
	for v in (data.get("discovered_dishes", []) as Array):
		discovered_dishes[String(v)] = true
	goals_changed.emit()
