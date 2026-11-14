class_name WorldState
extends RefCounted
## Unified Game Core coordinator owning shared systems and cross-module transactions.

var clock: GameClock
var wallet: Wallet
var inventory: Inventory
var farm: FarmSystem
var order_board: OrderBoard
var farm_upgrade: FarmUpgrade
var progression: ProgressionSystem
var production: ProductionSystem
var restaurant: RestaurantSystem
var automation: AutomationSystem
var home: HomeSystem
var pets: PetSystem
var garage: GarageSystem
var neighborhood: NeighborhoodSystem
var goals: GoalsSystem

var crops_by_id: Dictionary = {}
var crop_ids_sorted: Array[String] = []
var selected_crop_id: String = "carrot"

var order_cfg: Dictionary = {}
var catalog_cfg: Dictionary = {}
var levels_cfg: Dictionary = {}
var recipes_cfg: Dictionary = {}
var restaurant_cfg: Dictionary = {}
var automation_cfg: Dictionary = {}
var home_cfg: Dictionary = {}
var pets_cfg: Dictionary = {}
var garage_cfg: Dictionary = {}
var neighborhood_cfg: Dictionary = {}
var goals_cfg: Dictionary = {}
var farm_upgrade_cfg: Dictionary = {}
var inv_upgrade_cfg: Dictionary = {}

func _init() -> void:
	crops_by_id = BalanceLoader.load_all_crops()
	order_cfg = BalanceLoader.load_order_carrot()
	catalog_cfg = BalanceLoader.load_orders_catalog()
	levels_cfg = BalanceLoader.load_levels()
	recipes_cfg = BalanceLoader.load_production_recipes()
	restaurant_cfg = BalanceLoader.load_restaurant_hu_tieu()
	automation_cfg = BalanceLoader.load_automation_staff()
	home_cfg = BalanceLoader.load_home_furniture()
	pets_cfg = BalanceLoader.load_pets_config()
	garage_cfg = BalanceLoader.load_garage_config()
	neighborhood_cfg = BalanceLoader.load_neighborhood_config()
	goals_cfg = BalanceLoader.load_goals_config()
	farm_upgrade_cfg = BalanceLoader.load_farm_upgrade()
	inv_upgrade_cfg = BalanceLoader.load_inventory_upgrade()
	_sort_crop_ids()

	clock = GameClock.new()
	wallet = Wallet.new(int(farm_upgrade_cfg.get("starting_coins", 100)))
	inventory = Inventory.new(int(inv_upgrade_cfg.get("initial_capacity", 20)))
	farm = FarmSystem.new(
		int(farm_upgrade_cfg.get("total_plots", 12)),
		int(farm_upgrade_cfg.get("initial_unlocked_plots", 4))
	)
	progression = ProgressionSystem.new(levels_cfg)
	order_board = OrderBoard.new(order_cfg, catalog_cfg)
	order_board.ensure_slots(progression.level, clock)
	production = ProductionSystem.new(recipes_cfg)
	restaurant = RestaurantSystem.new(restaurant_cfg)
	automation = AutomationSystem.new(automation_cfg)
	home = HomeSystem.new(home_cfg)
	pets = PetSystem.new(pets_cfg)
	garage = GarageSystem.new(garage_cfg)
	neighborhood = NeighborhoodSystem.new(neighborhood_cfg)
	goals = GoalsSystem.new(goals_cfg)
	farm_upgrade = FarmUpgrade.new(farm_upgrade_cfg)

func _sort_crop_ids() -> void:
	crop_ids_sorted.clear()
	var list: Array[Dictionary] = []
	for cid in crops_by_id.keys():
		list.append(crops_by_id[cid] as Dictionary)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := int(a.get("grow_duration_sec", 0))
		var db := int(b.get("grow_duration_sec", 0))
		if da != db:
			return da < db
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	for cfg in list:
		crop_ids_sorted.append(String(cfg.get("id", "")))
	if not crops_by_id.has(selected_crop_id) and not crop_ids_sorted.is_empty():
		selected_crop_id = crop_ids_sorted[0]

func get_selected_crop_cfg() -> Dictionary:
	return crops_by_id.get(selected_crop_id, BalanceLoader.load_crop_carrot()) as Dictionary

func get_crop_cfg(crop_id: String) -> Dictionary:
	return crops_by_id.get(crop_id, get_selected_crop_cfg()) as Dictionary

func get_item_cfg(item_id: String) -> Dictionary:
	if crops_by_id.has(item_id):
		return crops_by_id[item_id] as Dictionary
	if production != null and production.recipes_by_id.has(item_id):
		return production.recipes_by_id[item_id] as Dictionary
	return {"id": item_id, "display_name": item_id, "sell_price": 5}

func get_all_known_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for cid in crop_ids_sorted:
		ids.append(cid)
	if production != null:
		for rid in production.recipe_ids_sorted:
			var out_id := String((production.recipes_by_id[rid] as Dictionary).get("output_id", rid))
			if not ids.has(out_id):
				ids.append(out_id)
	return ids

func is_crop_unlocked(crop_id: String) -> bool:
	return UnlockRules.is_crop_unlocked(crop_id, progression)

func select_crop(crop_id: String) -> Dictionary:
	if not crops_by_id.has(crop_id):
		return {"ok": false, "reason": "Giống cây không tồn tại."}
	if not is_crop_unlocked(crop_id):
		var req_lv := UnlockRules.get_required_level_for_crop(crop_id, progression)
		return {"ok": false, "reason": "Cần đạt Level %d để mở khóa giống này." % req_lv}
	selected_crop_id = crop_id
	return {"ok": true}

func get_min_unlocked_seed_cost() -> int:
	var min_cost := 999999
	for cid in crops_by_id.keys():
		if not is_crop_unlocked(String(cid)):
			continue
		var c := maxi(0, int((crops_by_id[cid] as Dictionary).get("seed_cost", 5)))
		if c < min_cost:
			min_cost = c
	return min_cost if min_cost < 999999 else 2

func is_economically_dead_ended() -> bool:
	return (
		wallet.balance < get_min_unlocked_seed_cost()
		and inventory.get_total_count() == 0
		and not farm.has_active_crops()
		and (production == null or production.queue.is_empty())
	)

func try_emergency_recovery() -> Dictionary:
	if not is_economically_dead_ended():
		return {"recovered": false}
	if not is_crop_unlocked(selected_crop_id):
		selected_crop_id = "carrot"
	var cfg := get_selected_crop_cfg()
	var needed := maxi(1, int(cfg.get("seed_cost", 5)))
	wallet.earn(needed)
	return {"recovered": true, "granted_coins": needed, "crop_id": selected_crop_id}

func plant_plot(plot_id: int) -> Dictionary:
	if not is_crop_unlocked(selected_crop_id):
		var req_lv := UnlockRules.get_required_level_for_crop(selected_crop_id, progression)
		return {"ok": false, "reason": "Giống cây cần Level %d." % req_lv}
	var recovery := try_emergency_recovery()
	var cfg := get_selected_crop_cfg()
	var res := farm.plant_plot(plot_id, cfg, wallet, clock)
	res["recovered_coins"] = int(recovery.get("granted_coins", 0))
	return res

func plant_all_empty() -> Dictionary:
	if not is_crop_unlocked(selected_crop_id):
		var req_lv := UnlockRules.get_required_level_for_crop(selected_crop_id, progression)
		return {"ok": false, "reason": "Giống cây cần Level %d." % req_lv}
	var recovery := try_emergency_recovery()
	var cfg := get_selected_crop_cfg()
	var res := farm.plant_all_empty(cfg, wallet, clock)
	res["recovered_coins"] = int(recovery.get("granted_coins", 0))
	return res

func harvest_plot(plot_id: int) -> Dictionary:
	var plot := farm.get_plot(plot_id)
	if plot == null:
		return {"ok": false, "reason": "Ô đất không tồn tại."}
	var cid := plot.crop_id
	var cfg := get_crop_cfg(cid)
	var res := farm.harvest_plot(plot_id, cfg, inventory)
	if bool(res.get("ok", false)):
		goals.record_harvest(cid, 1)
	return res

func harvest_all_ready() -> Dictionary:
	var res := farm.harvest_all_ready(crops_by_id, inventory)
	var cnt := int(res.get("harvested_plots", 0))
	if cnt > 0:
		goals.record_harvest("", cnt)
	return res

func sell_crop(item_id: String, count: int = 1) -> Dictionary:
	if count <= 0:
		return {"ok": false, "reason": "Số lượng bán phải > 0."}
	if not inventory.has_item(item_id, count):
		return {"ok": false, "reason": "Không đủ %s trong kho." % item_id}
	var cfg := get_item_cfg(item_id)
	var unit_price := maxi(1, int(cfg.get("sell_price", 5)))
	if not inventory.remove_item(item_id, count):
		return {"ok": false, "reason": "Không thể trừ kho."}
	var total := unit_price * count
	wallet.earn(total)
	return {
		"ok": true,
		"crop_id": item_id,
		"sold": count,
		"earned": total,
		"display_name": String(cfg.get("display_name", item_id))
	}

func start_production(recipe_id: String) -> Dictionary:
	return production.start_recipe(recipe_id, inventory, clock, progression.level)

func collect_production(job_idx: int) -> Dictionary:
	var res := production.collect_job(job_idx, inventory)
	if bool(res.get("ok", false)):
		goals.record_craft(String(res.get("recipe_id", "")), 1)
	return res

func collect_all_production() -> Dictionary:
	var res := production.collect_all_ready(inventory)
	var cnt := int(res.get("collected", 0))
	if cnt > 0:
		goals.record_craft("", cnt)
	return res

func upgrade_production_slot() -> Dictionary:
	return production.upgrade_slot(wallet)

func unlock_restaurant() -> Dictionary:
	return restaurant.unlock_restaurant(wallet, progression.level)

func cook_dish(dish_id: String) -> Dictionary:
	return restaurant.start_cook(dish_id, inventory, clock)

func serve_restaurant_customer(cust_idx: int) -> Dictionary:
	var res := restaurant.serve_customer(cust_idx, wallet, progression)
	if bool(res.get("ok", false)):
		goals.record_dish_served(String(res.get("dish_id", "")), 1)
	return res

func dismiss_restaurant_customer(cust_idx: int) -> Dictionary:
	return restaurant.dismiss_customer(cust_idx, progression.level)

func upgrade_restaurant_kitchen() -> Dictionary:
	return restaurant.upgrade_kitchen(wallet)

func upgrade_restaurant_tables() -> Dictionary:
	return restaurant.upgrade_tables(wallet, progression.level)

func step_automation() -> Dictionary:
	var res := automation.step(clock, inventory, wallet, progression, production, restaurant)
	if int(res.get("crafted_collected", 0)) > 0:
		goals.record_craft("", int(res["crafted_collected"]))
	if int(res.get("dishes_served", 0)) > 0:
		goals.record_dish_served("", int(res["dishes_served"]))
	garage.tick(clock)
	var g_res := garage.step_automation(clock, inventory, wallet, progression, home, pets)
	if int(g_res["claimed"]) > 0:
		goals.record_delivery(int(g_res["claimed"]))
	res["garage_claimed"] = int(g_res["claimed"])
	res["garage_dispatched"] = int(g_res["dispatched"])
	return res

func deliver_order_slot(slot_idx: int) -> Dictionary:
	var res := order_board.deliver_slot(slot_idx, inventory, wallet, progression, clock)
	if bool(res.get("ok", false)):
		goals.record_order(1)
	return res

func skip_order_slot(slot_idx: int) -> Dictionary:
	return order_board.skip_slot(slot_idx, progression.level, clock)

# P1 compatibility helper
func deliver_order() -> Dictionary:
	return order_board.deliver(inventory, wallet)

func unlock_plot(plot_id: int) -> Dictionary:
	if not UnlockRules.is_plot_tier_unlocked(plot_id, progression):
		var req_lv := UnlockRules.get_required_level_for_plot(plot_id)
		return {"ok": false, "reason": "Ô #%d cần đạt Level %d để mở khóa." % [plot_id + 1, req_lv]}
	return farm_upgrade.unlock_specific_plot(plot_id, farm, wallet)

func unlock_next_plot() -> Dictionary:
	var target_id := farm.get_first_locked_plot_id()
	if target_id == -1:
		return {"ok": false, "reason": "Tất cả ô đất đã được mở khóa."}
	return unlock_plot(target_id)

func can_unlock_next_plot() -> bool:
	var target_id := farm.get_first_locked_plot_id()
	if target_id == -1:
		return false
	return UnlockRules.is_plot_tier_unlocked(target_id, progression) and wallet.can_afford(farm_upgrade.unlock_cost)

func can_upgrade_inventory() -> bool:
	var max_cap := int(inv_upgrade_cfg.get("max_capacity", 100))
	return inventory.capacity < max_cap and wallet.can_afford(get_next_inventory_upgrade_cost())

func get_next_inventory_upgrade_cost() -> int:
	var init_cap := int(inv_upgrade_cfg.get("initial_capacity", 20))
	var step := maxi(1, int(inv_upgrade_cfg.get("capacity_step", 10)))
	var upgrades_done := maxi(0, int((inventory.capacity - init_cap) / step))
	var base_cost := int(inv_upgrade_cfg.get("base_upgrade_cost", 50))
	var cost_step := int(inv_upgrade_cfg.get("cost_step", 50))
	return base_cost + upgrades_done * cost_step

func upgrade_inventory() -> Dictionary:
	var max_cap := int(inv_upgrade_cfg.get("max_capacity", 100))
	if inventory.capacity >= max_cap:
		return {"ok": false, "reason": "Kho đã đạt sức chứa tối đa (%d)." % max_cap}
	var cost := get_next_inventory_upgrade_cost()
	if not wallet.can_afford(cost):
		return {"ok": false, "reason": "Không đủ xu nâng cấp kho (cần %d xu)." % cost}
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không thể trừ xu."}
	var step := maxi(1, int(inv_upgrade_cfg.get("capacity_step", 10)))
	inventory.upgrade_capacity(step)
	return {"ok": true, "cost": cost, "new_capacity": inventory.capacity}

func save(path: String = SaveManager.DEFAULT_SAVE_PATH) -> bool:
	return SaveManager.save_game(clock, wallet, inventory, farm, path, selected_crop_id, progression, order_board, production, restaurant, automation, home, pets, garage, neighborhood, goals)

func load_state(path: String = SaveManager.DEFAULT_SAVE_PATH) -> Dictionary:
	var res := SaveManager.load_game(clock, wallet, inventory, farm, path, progression, order_board, production, restaurant, automation, home, pets, garage, neighborhood, goals)
	if bool(res.get("loaded", false)):
		var loaded_crop := String(res.get("selected_crop_id", "carrot"))
		if crops_by_id.has(loaded_crop) and is_crop_unlocked(loaded_crop):
			selected_crop_id = loaded_crop
		else:
			selected_crop_id = "carrot"
		var offline_sec := int(res.get("offline_elapsed", 0))
		var off_summary := automation.simulate_offline(offline_sec, clock, inventory, wallet, progression, production, restaurant)
		res["offline_summary"] = off_summary
		if offline_sec > 0:
			save(path)
	return res

func reset_game(path: String = SaveManager.DEFAULT_SAVE_PATH) -> void:
	SaveManager.reset_save(path)
	clock.reset()
	wallet.set_balance(int(farm_upgrade_cfg.get("starting_coins", 100)))
	inventory.set_capacity(int(inv_upgrade_cfg.get("initial_capacity", 20)))
	inventory.clear_all()
	farm.reset_plots(
		int(farm_upgrade_cfg.get("total_plots", 12)),
		int(farm_upgrade_cfg.get("initial_unlocked_plots", 4))
	)
	progression.reset()
	order_board.slots.clear()
	order_board.slot_cooldowns.clear()
	order_board.ensure_slots(progression.level, clock)
	production.reset()
	restaurant.reset()
	automation.reset()
	home.reset()
	pets.reset()
	garage.reset()
	neighborhood.reset()
	goals.reset()
	selected_crop_id = "carrot" if crops_by_id.has("carrot") else crop_ids_sorted[0]
