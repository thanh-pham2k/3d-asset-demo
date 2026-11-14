class_name AutomationSystem
extends RefCounted
## Manages hired staff automation, priorities, upgrades, and bounded offline simulation.

signal automation_changed()

var max_offline_sec: int = 14400
var offline_step_sec: int = 5
var prep_cfg: Dictionary = {}
var chef_cfg: Dictionary = {}

# Persistent state
var prep_hired: bool = false
var prep_level: int = 1
var prep_enabled: bool = true
var prep_priority_recipe: String = "auto"

var chef_hired: bool = false
var chef_level: int = 1
var chef_enabled: bool = true
var chef_priority: String = "special_first" # "special_first" | "first_waiting"

var last_offline_summary: Dictionary = {}

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)
	reset()

func apply_config(cfg: Dictionary) -> void:
	max_offline_sec = maxi(60, int(cfg.get("max_offline_sec", 14400)))
	offline_step_sec = maxi(1, int(cfg.get("offline_step_sec", 5)))
	prep_cfg = (cfg.get("prep_helper", {}) as Dictionary).duplicate(true)
	chef_cfg = (cfg.get("hu_tieu_chef", {}) as Dictionary).duplicate(true)

func reset() -> void:
	prep_hired = false
	prep_level = 1
	prep_enabled = true
	prep_priority_recipe = "auto"

	chef_hired = false
	chef_level = 1
	chef_enabled = true
	chef_priority = "special_first"
	last_offline_summary.clear()
	automation_changed.emit()

func hire_prep(wallet: Wallet, player_level: int) -> Dictionary:
	if prep_hired:
		return {"ok": false, "reason": "Đã thuê Phụ bếp Chế biến."}
	var req_lv := int(prep_cfg.get("unlock_level", 1))
	if player_level < req_lv:
		return {"ok": false, "reason": "Cần đạt Level %d." % req_lv}
	var cost := maxi(0, int(prep_cfg.get("hire_cost", 90)))
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu thuê Phụ bếp (cần %d xu)." % cost}
	prep_hired = true
	prep_level = 1
	prep_enabled = true
	automation_changed.emit()
	return {"ok": true, "cost": cost}

func hire_chef(wallet: Wallet, player_level: int, restaurant_unlocked: bool) -> Dictionary:
	if chef_hired:
		return {"ok": false, "reason": "Đã thuê Đầu bếp Hủ Tiếu."}
	if not restaurant_unlocked:
		return {"ok": false, "reason": "Hãy mở Quán Hủ Tiếu trước."}
	var req_lv := int(chef_cfg.get("unlock_level", 2))
	if player_level < req_lv:
		return {"ok": false, "reason": "Cần đạt Level %d." % req_lv}
	var cost := maxi(0, int(chef_cfg.get("hire_cost", 160)))
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu thuê Đầu bếp (cần %d xu)." % cost}
	chef_hired = true
	chef_level = 1
	chef_enabled = true
	automation_changed.emit()
	return {"ok": true, "cost": cost}

func get_prep_upgrade_cost() -> int:
	var costs: Array = prep_cfg.get("upgrade_costs", [100, 200]) as Array
	var idx := prep_level - 1
	if idx < 0 or idx >= costs.size():
		return 0
	return int(costs[idx])

func upgrade_prep(wallet: Wallet) -> Dictionary:
	if not prep_hired:
		return {"ok": false, "reason": "Chưa thuê Phụ bếp."}
	var max_lv := int(prep_cfg.get("max_level", 3))
	if prep_level >= max_lv:
		return {"ok": false, "reason": "Phụ bếp đã đạt cấp tối đa."}
	var cost := get_prep_upgrade_cost()
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu nâng cấp Phụ bếp (cần %d xu)." % cost}
	prep_level += 1
	automation_changed.emit()
	return {"ok": true, "cost": cost, "new_level": prep_level}

func get_chef_upgrade_cost() -> int:
	var costs: Array = chef_cfg.get("upgrade_costs", [140, 260]) as Array
	var idx := chef_level - 1
	if idx < 0 or idx >= costs.size():
		return 0
	return int(costs[idx])

func upgrade_chef(wallet: Wallet) -> Dictionary:
	if not chef_hired:
		return {"ok": false, "reason": "Chưa thuê Đầu bếp."}
	var max_lv := int(chef_cfg.get("max_level", 3))
	if chef_level >= max_lv:
		return {"ok": false, "reason": "Đầu bếp đã đạt cấp tối đa."}
	var cost := get_chef_upgrade_cost()
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu nâng cấp Đầu bếp (cần %d xu)." % cost}
	chef_level += 1
	automation_changed.emit()
	return {"ok": true, "cost": cost, "new_level": chef_level}

func _get_actions_per_cycle(cfg: Dictionary, lv: int) -> int:
	var arr: Array = cfg.get("actions_per_cycle", [1, 2, 3]) as Array
	var idx := clampi(lv - 1, 0, arr.size() - 1)
	return maxi(1, int(arr[idx])) if not arr.is_empty() else 1

func step(
	clock: GameClock,
	inventory: Inventory,
	wallet: Wallet,
	progression: ProgressionSystem,
	production: ProductionSystem,
	restaurant: RestaurantSystem
) -> Dictionary:
	var crafted_collected := 0
	var dishes_served := 0
	var coins_earned := 0
	var xp_earned := 0

	# 1. Prep Helper: collect ready & queue prioritized recipe using real Inventory
	if prep_hired and prep_enabled and production != null:
		var col_res := production.collect_all_ready(inventory)
		crafted_collected += int(col_res.get("collected", 0))

		var budget := _get_actions_per_cycle(prep_cfg, prep_level)
		while budget > 0 and production.queue.size() < production.max_slots:
			var rid := _pick_recipe_for_prep(production, inventory, progression.level)
			if rid == "":
				break
			var s_res := production.start_recipe(rid, inventory, clock, progression.level)
			if not bool(s_res.get("ok", false)):
				break
			budget -= 1

	# 2. Hu Tieu Chef: serve ready dishes & cook for waiting customers using real Inventory
	if chef_hired and chef_enabled and restaurant != null and restaurant.is_unlocked:
		var budget := _get_actions_per_cycle(chef_cfg, chef_level)
		# Serve matching ready dishes
		var served_any := true
		while served_any and budget > 0:
			served_any = false
			var target_idx := _find_servable_customer_idx(restaurant)
			if target_idx != -1:
				var srv := restaurant.serve_customer(target_idx, wallet, progression)
				if bool(srv.get("ok", false)):
					dishes_served += 1
					coins_earned += int(srv.get("reward_coins", 0))
					xp_earned += int(srv.get("reward_xp", 0))
					budget -= 1
					served_any = true

		# Cook for waiting customers not yet cooking/ready
		var cook_budget := _get_actions_per_cycle(chef_cfg, chef_level)
		while cook_budget > 0 and restaurant.cooking_queue.size() < restaurant.kitchen_slots:
			var next_dish := _pick_dish_to_cook(restaurant, inventory)
			if next_dish == "":
				break
			var c_res := restaurant.start_cook(next_dish, inventory, clock)
			if not bool(c_res.get("ok", false)):
				break
			cook_budget -= 1

	return {
		"crafted_collected": crafted_collected,
		"dishes_served": dishes_served,
		"coins_earned": coins_earned,
		"xp_earned": xp_earned
	}

func _pick_recipe_for_prep(production: ProductionSystem, inventory: Inventory, player_level: int) -> String:
	if prep_priority_recipe != "auto":
		var chk := production.can_start_recipe(prep_priority_recipe, inventory, player_level)
		return prep_priority_recipe if bool(chk.get("ok", false)) else ""
	for rid in production.recipe_ids_sorted:
		var chk := production.can_start_recipe(rid, inventory, player_level)
		if bool(chk.get("ok", false)):
			return rid
	return ""

func _find_servable_customer_idx(restaurant: RestaurantSystem) -> int:
	if chef_priority == "special_first":
		for i in range(restaurant.customers.size()):
			var c := restaurant.customers[i]
			if String(c.get("type", "normal")) == "special":
				if restaurant.find_ready_dish_idx(String(c.get("dish_id", ""))) != -1:
					return i
	for i in range(restaurant.customers.size()):
		var c := restaurant.customers[i]
		if restaurant.find_ready_dish_idx(String(c.get("dish_id", ""))) != -1:
			return i
	return -1

func _pick_dish_to_cook(restaurant: RestaurantSystem, inventory: Inventory) -> String:
	var order_indices: Array[int] = []
	if chef_priority == "special_first":
		for i in range(restaurant.customers.size()):
			if String(restaurant.customers[i].get("type", "normal")) == "special":
				order_indices.append(i)
	for i in range(restaurant.customers.size()):
		if not order_indices.has(i):
			order_indices.append(i)

	for idx in order_indices:
		var dish_id := String(restaurant.customers[idx].get("dish_id", ""))
		if dish_id == "":
			continue
		# Skip if this dish is already cooking or ready in kitchen
		var already_in_kitchen := false
		for job in restaurant.cooking_queue:
			if String(job.get("dish_id", "")) == dish_id:
				already_in_kitchen = true
				break
		if already_in_kitchen:
			continue
		if bool(restaurant.can_cook(dish_id, inventory).get("ok", false)):
			return dish_id
	return ""

func simulate_offline(
	raw_offline_sec: int,
	real_clock: GameClock,
	inventory: Inventory,
	wallet: Wallet,
	progression: ProgressionSystem,
	production: ProductionSystem,
	restaurant: RestaurantSystem
) -> Dictionary:
	var summary := {
		"raw_offline_sec": maxi(0, raw_offline_sec),
		"capped_offline_sec": 0,
		"was_capped": false,
		"crafted_collected": 0,
		"dishes_served": 0,
		"coins_earned": 0,
		"xp_earned": 0
	}
	if raw_offline_sec <= 0 or (not prep_hired and not chef_hired):
		last_offline_summary = summary
		return summary

	var capped := mini(raw_offline_sec, max_offline_sec)
	summary["capped_offline_sec"] = capped
	summary["was_capped"] = raw_offline_sec > max_offline_sec

	var end_unix := real_clock.now()
	var start_unix := end_unix - capped
	var base_sys := int(Time.get_unix_time_from_system())
	var sim_clock := GameClock.new()

	var t := start_unix
	while t <= end_unix:
		sim_clock.set_offset(t - base_sys)
		production.tick(sim_clock)
		restaurant.tick(sim_clock)
		var res := step(sim_clock, inventory, wallet, progression, production, restaurant)
		summary["crafted_collected"] = int(summary["crafted_collected"]) + int(res["crafted_collected"])
		summary["dishes_served"] = int(summary["dishes_served"]) + int(res["dishes_served"])
		summary["coins_earned"] = int(summary["coins_earned"]) + int(res["coins_earned"])
		summary["xp_earned"] = int(summary["xp_earned"]) + int(res["xp_earned"])

		# Early exit if nothing is processing/cooking and nothing can be queued
		var has_work := not production.queue.is_empty() or not restaurant.cooking_queue.is_empty()
		if not has_work and int(res["crafted_collected"]) == 0 and int(res["dishes_served"]) == 0:
			break
		if t == end_unix:
			break
		t = mini(end_unix, t + offline_step_sec)

	last_offline_summary = summary
	return summary

func to_dict() -> Dictionary:
	return {
		"prep_hired": prep_hired,
		"prep_level": prep_level,
		"prep_enabled": prep_enabled,
		"prep_priority_recipe": prep_priority_recipe,
		"chef_hired": chef_hired,
		"chef_level": chef_level,
		"chef_enabled": chef_enabled,
		"chef_priority": chef_priority
	}

func load_from_dict(d: Dictionary) -> void:
	prep_hired = bool(d.get("prep_hired", false))
	prep_level = clampi(int(d.get("prep_level", 1)), 1, int(prep_cfg.get("max_level", 3)))
	prep_enabled = bool(d.get("prep_enabled", true))
	prep_priority_recipe = String(d.get("prep_priority_recipe", "auto"))

	chef_hired = bool(d.get("chef_hired", false))
	chef_level = clampi(int(d.get("chef_level", 1)), 1, int(chef_cfg.get("max_level", 3)))
	chef_enabled = bool(d.get("chef_enabled", true))
	chef_priority = String(d.get("chef_priority", "special_first"))
	automation_changed.emit()
