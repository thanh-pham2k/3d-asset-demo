class_name DailyObjectiveManager
extends Node

## Manages Daily Objectives, 7-Day Weekly Objectives, and Permanent Milestones.
## Filters objectives by accessible gameplay systems, prevents consecutive-day
## repetition, awards rewards once via HouseholdWallet, and provides a compact
## Progression Panel (key J) alongside a minimal gameplay HUD.

signal objective_completed(objective_id: String, reward: int)
signal all_objectives_completed()
signal weekly_objective_completed(objective_id: String, reward: int)
signal milestone_unlocked(milestone_id: String, reward: int)
signal objectives_updated()

@export var current_day: int = 1
var objectives: Array[Dictionary] = []
var completed_count: int = 0
var last_daily_combo_ids: Array[String] = []

var current_week: int = 1
var weekly_objectives: Array[Dictionary] = []
var milestones: Array[Dictionary] = []
var neighbor_interactions: Dictionary = {}

# Optional override for deterministic simulation/testing of locked systems
var accessibility_override: Dictionary = {}

# Minimal HUD + Compact Progression Panel
var objective_label: Label
var hud_toggle_button: Button
var progression_layer: CanvasLayer
var progression_panel: PanelContainer
var progression_title_label: Label
var progression_subtitle_label: Label
var progression_list_container: VBoxContainer
var tab_daily_btn: Button
var tab_weekly_btn: Button
var tab_milestone_btn: Button
var active_tab: String = "daily"

const MILESTONE_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "ms_first_repair",
		"title": "Thợ Sửa Xe Khởi Nghiệp",
		"desc": "Hoàn thành lần sửa xe đầu tiên tại tiệm",
		"unlock_req": "Phục vụ 1 khách tại Tiệm Sửa Xe",
		"unlock_text": "Danh hiệu: Thợ Máy Xóm Nhỏ",
		"reward": 10000
	},
	{
		"id": "ms_first_noodle",
		"title": "Đầu Bếp Hủ Tiếu",
		"desc": "Phục vụ tô hủ tiếu đầu tiên cho khách",
		"unlock_req": "Hoàn thành 1 đơn tại Quán Hủ Tiếu",
		"unlock_text": "Danh hiệu: Chủ Quán Hủ Tiếu",
		"reward": 10000
	},
	{
		"id": "ms_first_harvest",
		"title": "Nông Dân Sân Vườn",
		"desc": "Thu hoạch lứa rau củ đầu tiên từ vườn nhà",
		"unlock_req": "Thu hoạch 1 luống rau chín",
		"unlock_text": "Mở chuỗi cung ứng rau sạch cho quán",
		"reward": 8000
	},
	{
		"id": "ms_first_house_upgrade",
		"title": "Tổ Ấm Khang Trang",
		"desc": "Nâng cấp ngôi nhà lần đầu tiên",
		"unlock_req": "Nâng cấp Nhà lên Cấp 2 trở lên",
		"unlock_text": "Mở rộng không gian sống & nội thất",
		"reward": 15000
	},
	{
		"id": "ms_first_vip",
		"title": "Khách Quý Ghé Thăm",
		"desc": "Phục vụ thành công vị khách VIP đầu tiên",
		"unlock_req": "Hoàn thành 1 đơn khách VIP",
		"unlock_text": "Tăng uy tín khu phố",
		"reward": 15000
	},
	{
		"id": "ms_business_lvl_3",
		"title": "Tiệm Ăn Nên Làm Ra",
		"desc": "Đưa một cửa hàng đạt Cấp 3",
		"unlock_req": "Đạt Cấp 3 ở Tiệm Sửa Xe hoặc Quán Hủ Tiếu",
		"unlock_text": "Danh hiệu: Doanh Nhân Khu Phố",
		"reward": 25000
	},
	{
		"id": "ms_close_neighbor",
		"title": "Hàng Xóm Thân Thiết",
		"desc": "Gắn kết tình cảm với người dân trong khu phố",
		"unlock_req": "Trò chuyện 3 lần với hàng xóm",
		"unlock_text": "Danh hiệu: Hàng Xóm Thân Thiết",
		"reward": 10000
	}
]

func _ready() -> void:
	add_to_group("daily_objective_manager")
	_ensure_milestones_initialized()
	_build_hud()
	_build_progression_panel()
	objectives_updated.connect(_refresh_hud)
	objectives_updated.connect(_refresh_progression_panel)
	call_deferred("_discover_dependencies")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			get_viewport().set_input_as_handled()
			toggle_progression_panel()
		elif event.keycode == KEY_ESCAPE and is_instance_valid(progression_layer) and progression_layer.visible:
			get_viewport().set_input_as_handled()
			set_progression_panel_visible(false)

func _discover_dependencies() -> void:
	var daily_loop := get_tree().get_first_node_in_group("daily_loop_manager") as DailyLoopManager
	if is_instance_valid(daily_loop):
		if not daily_loop.day_advanced.is_connected(_on_day_started):
			daily_loop.day_advanced.connect(_on_day_started)

	var garage := get_tree().get_first_node_in_group("garage_business") as GarageBusiness
	if is_instance_valid(garage):
		if not garage.order_completed.is_connected(_on_business_order_completed):
			garage.order_completed.connect(_on_business_order_completed)
		if not garage.level_up.is_connected(_on_business_level_up):
			garage.level_up.connect(_on_business_level_up)

	var hutieu := get_tree().get_first_node_in_group("hutieu_business") as HuTieuBusiness
	if is_instance_valid(hutieu):
		if not hutieu.order_completed.is_connected(_on_business_order_completed):
			hutieu.order_completed.connect(_on_business_order_completed)
		if not hutieu.level_up.is_connected(_on_business_level_up):
			hutieu.level_up.connect(_on_business_level_up)

	var house_mgr := get_tree().get_first_node_in_group("house_progression_manager") as HouseProgressionManager
	if is_instance_valid(house_mgr):
		if not house_mgr.house_upgraded.is_connected(_on_house_upgraded):
			house_mgr.house_upgraded.connect(_on_house_upgraded)

	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		if not econ.purchase_completed.is_connected(_on_purchase_completed):
			econ.purchase_completed.connect(_on_purchase_completed)
		if not econ.produce_sold.is_connected(_on_produce_sold):
			econ.produce_sold.connect(_on_produce_sold)
		if is_instance_valid(econ.wallet) and not econ.wallet.balance_changed.is_connected(_on_wallet_balance_changed):
			econ.wallet.balance_changed.connect(_on_wallet_balance_changed)
		var saved := EconomySaveSystem.load_objective_data(econ.save_file_path)
		if not saved.is_empty():
			apply_save_data(saved)

	var day := daily_loop.current_day if is_instance_valid(daily_loop) else current_day
	var expected_week := get_week_for_day(day)
	if weekly_objectives.is_empty() or current_week != expected_week:
		generate_weekly_objectives(expected_week)
	if objectives.is_empty() or current_day != day:
		generate_daily_objectives(day)

	var room := get_tree().get_first_node_in_group("room") as Room
	if is_instance_valid(room) and is_instance_valid(room.placement_manager):
		if not room.placement_manager.placement_confirmed.is_connected(_on_furniture_placed):
			room.placement_manager.placement_confirmed.connect(_on_furniture_placed)

	var pet_mgr := get_tree().get_first_node_in_group("pet_manager") as PetManager
	if is_instance_valid(pet_mgr):
		if not pet_mgr.pet_interacted.is_connected(_on_pet_action):
			pet_mgr.pet_interacted.connect(_on_pet_action)

	var garden_mgr := get_tree().get_first_node_in_group("garden_manager") as GardenManager
	if is_instance_valid(garden_mgr):
		if not garden_mgr.plot_added.is_connected(_connect_plot_signals):
			garden_mgr.plot_added.connect(_connect_plot_signals)
		for plot in garden_mgr.plots:
			_connect_plot_signals(plot)

	var npc_mgr := get_tree().get_first_node_in_group("npc_manager")
	if not is_instance_valid(npc_mgr):
		npc_mgr = get_node_or_null("../NPCManager")
	if is_instance_valid(npc_mgr) and npc_mgr.has_signal("npc_interaction_started"):
		if not npc_mgr.npc_interaction_started.is_connected(_on_npc_interaction_started):
			npc_mgr.npc_interaction_started.connect(_on_npc_interaction_started)

func _connect_plot_signals(plot: FarmPlot) -> void:
	if not is_instance_valid(plot):
		return
	if plot.has_signal("crop_planted") and not plot.crop_planted.is_connected(_on_crop_planted):
		plot.crop_planted.connect(_on_crop_planted)
	if not plot.crop_watered.is_connected(_on_crop_watered):
		plot.crop_watered.connect(_on_crop_watered)
	if not plot.crop_harvested.is_connected(_on_crop_harvested):
		plot.crop_harvested.connect(_on_crop_harvested)

static func get_week_for_day(day: int) -> int:
	return ((maxi(1, day) - 1) / 7) + 1

static func get_day_in_week(day: int) -> int:
	return ((maxi(1, day) - 1) % 7) + 1

func _get_accessibility_profile() -> Dictionary:
	var profile := {
		"has_garage": false,
		"has_hutieu": false,
		"has_garden": false,
		"has_active_crops": false,
		"has_pet": false,
		"has_house_furniture": false,
		"has_shop": false,
		"can_switch_character": false,
		"max_business_level": 1,
		"house_level": 1,
		"plot_count": 0,
		"all_business_upgrades_owned": false
	}
	if is_inside_tree():
		var garage := get_tree().get_first_node_in_group("garage_business") as GarageBusiness
		var hutieu := get_tree().get_first_node_in_group("hutieu_business") as HuTieuBusiness
		profile["has_garage"] = is_instance_valid(garage)
		profile["has_hutieu"] = is_instance_valid(hutieu)
		var max_lvl := 1
		if is_instance_valid(garage):
			max_lvl = maxi(max_lvl, garage.business_level)
		if is_instance_valid(hutieu):
			max_lvl = maxi(max_lvl, hutieu.business_level)
		profile["max_business_level"] = max_lvl

		var garden := get_tree().get_first_node_in_group("garden_manager") as GardenManager
		if is_instance_valid(garden) and garden.plots.size() > 0:
			profile["has_garden"] = true
			profile["plot_count"] = garden.plots.size()
			for plot in garden.plots:
				if is_instance_valid(plot) and plot.crop_id != "":
					profile["has_active_crops"] = true
					break

		var pet_mgr := get_tree().get_first_node_in_group("pet_manager") as PetManager
		profile["has_pet"] = is_instance_valid(pet_mgr)

		var room := get_tree().get_first_node_in_group("room") as Room
		var house_mgr := get_tree().get_first_node_in_group("house_progression_manager") as HouseProgressionManager
		profile["has_house_furniture"] = is_instance_valid(room) or is_instance_valid(house_mgr)
		if is_instance_valid(house_mgr):
			profile["house_level"] = house_mgr.house_level

		var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		profile["has_shop"] = is_instance_valid(econ)
		if is_instance_valid(econ) and is_instance_valid(econ.inventory):
			var inv := econ.inventory
			profile["all_business_upgrades_owned"] = (
				inv.is_upgrade_owned("upg_garage_tools")
				and inv.is_upgrade_owned("upg_garage_second_bay")
				and inv.is_upgrade_owned("upg_hutieu_quick_stove")
				and inv.is_upgrade_owned("upg_hutieu_extra_table")
			)

		var coop_mgr := get_tree().get_first_node_in_group("coop_manager")
		if is_instance_valid(coop_mgr) and "is_coop_active" in coop_mgr:
			profile["can_switch_character"] = bool(coop_mgr.is_coop_active)

	for k in accessibility_override:
		profile[k] = accessibility_override[k]
	return profile

func _build_daily_candidate(id: String, day: int, profile: Dictionary, is_primary: bool) -> Dictionary:
	var has_garage: bool = bool(profile.get("has_garage", false))
	var has_hutieu: bool = bool(profile.get("has_hutieu", false))
	var biz_dest := "Tiệm Sửa Xe / Quán Hủ Tiếu"
	if has_garage and not has_hutieu:
		biz_dest = "Tiệm Sửa Xe"
	elif has_hutieu and not has_garage:
		biz_dest = "Quán Hủ Tiếu"

	match id:
		"obj_serve_customers":
			var cust_target := 2 if day <= 2 else 3
			return {
				"id": id, "category": "work",
				"title": "Phục vụ khách hàng",
				"desc": "Phục vụ %d khách tại %s" % [cust_target, biz_dest],
				"destination": biz_dest,
				"target": cust_target, "current": 0, "reward": 10000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_daily_revenue":
			var rev_target := 40000 if day <= 2 else 60000
			return {
				"id": id, "category": "earn",
				"title": "Thu nhập trong ngày",
				"desc": "Kiếm %s từ kinh doanh hoặc bán nông sản" % HouseholdWallet.format_money(rev_target),
				"destination": "Tiệm / Chợ Dân Sinh",
				"target": rev_target, "current": 0, "reward": 10000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_service_streak":
			return {
				"id": id, "category": "service",
				"title": "Phục vụ tận tâm",
				"desc": "Phục vụ 2 khách liên tiếp không để khách bỏ đi",
				"destination": biz_dest,
				"target": 2, "current": 0, "reward": 9000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_care_pet":
			return {
				"id": id, "category": "pet",
				"title": "Chăm sóc mèo cưng",
				"desc": "Cho bé mèo Miu Miu ăn hạt, uống nước hoặc vuốt ve",
				"destination": "Nhà Chung",
				"target": 1, "current": 0, "reward": 5000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_water_crops":
			return {
				"id": id, "category": "farm",
				"title": "Tưới nước vườn rau",
				"desc": "Tưới nước cho ít nhất 1 luống rau sau nhà",
				"destination": "Vườn Rau Gia Đình",
				"target": 1, "current": 0, "reward": 5000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_harvest_produce":
			return {
				"id": id, "category": "farm",
				"title": "Thu hoạch nông sản",
				"desc": "Thu hoạch rau củ chín từ vườn sau nhà",
				"destination": "Vườn Rau Gia Đình",
				"target": 1, "current": 0, "reward": 8000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_plant_crops":
			return {
				"id": id, "category": "farm",
				"title": "Gieo hạt vườn nhà",
				"desc": "Gieo 1 lứa hạt giống mới vào luống đất",
				"destination": "Vườn Rau Gia Đình",
				"target": 1, "current": 0, "reward": 5000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_buy_supplies":
			return {
				"id": id, "category": "shop",
				"title": "Mua sắm vật tư",
				"desc": "Mua phụ tùng, nguyên liệu hoặc hạt giống tại cửa hàng",
				"destination": "Chợ / Cửa Hàng",
				"target": 1, "current": 0, "reward": 6000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		"obj_furniture":
			return {
				"id": id, "category": "home",
				"title": "Trang trí nhà",
				"desc": "Mua hoặc đặt một món nội thất mới",
				"destination": "Tiệm Nội Thất / Nhà",
				"target": 1, "current": 0, "reward": 6000,
				"is_completed": false, "is_primary": is_primary, "is_optional": true
			}
		_:
			return {}

func _is_daily_candidate_accessible(id: String, profile: Dictionary) -> bool:
	var has_biz := bool(profile.get("has_garage", false)) or bool(profile.get("has_hutieu", false))
	match id:
		"obj_serve_customers", "obj_service_streak":
			return has_biz
		"obj_daily_revenue":
			return has_biz or bool(profile.get("has_garden", false))
		"obj_care_pet":
			return bool(profile.get("has_pet", false))
		"obj_water_crops", "obj_plant_crops":
			return bool(profile.get("has_garden", false))
		"obj_harvest_produce":
			return bool(profile.get("has_garden", false)) and bool(profile.get("has_active_crops", false))
		"obj_buy_supplies":
			return bool(profile.get("has_shop", false))
		"obj_furniture":
			return bool(profile.get("has_house_furniture", false))
		_:
			return false

func generate_daily_objectives(day: int) -> void:
	current_day = maxi(1, day)
	objectives.clear()
	completed_count = 0
	var profile := _get_accessibility_profile()

	# 1. Pick Primary Objective (alternate when possible to avoid identical daily combos)
	var primary_pool: Array[String] = []
	for pid in ["obj_serve_customers", "obj_daily_revenue", "obj_service_streak"]:
		if _is_daily_candidate_accessible(pid, profile):
			primary_pool.append(pid)
	if primary_pool.is_empty():
		primary_pool.append("obj_daily_revenue")

	var primary_id := primary_pool[(current_day - 1) % primary_pool.size()]
	if primary_pool.size() > 1 and primary_id in last_daily_combo_ids and current_day % 2 == 0:
		primary_id = primary_pool[current_day % primary_pool.size()]
	objectives.append(_build_daily_candidate(primary_id, current_day, profile, true))

	# 2. Pick 2-3 diverse optional objectives from distinct categories without repeating exact combo
	var optional_pool: Array[String] = [
		"obj_daily_revenue", "obj_service_streak", "obj_care_pet",
		"obj_harvest_produce", "obj_water_crops", "obj_plant_crops",
		"obj_buy_supplies", "obj_furniture", "obj_serve_customers"
	]
	var eligible: Array[String] = []
	for cid in optional_pool:
		if cid == primary_id:
			continue
		if _is_daily_candidate_accessible(cid, profile):
			eligible.append(cid)

	# Prioritize candidates that were NOT in yesterday's combo to avoid consecutive repeats
	var fresh_candidates: Array[String] = []
	var repeat_candidates: Array[String] = []
	for cid in eligible:
		if cid in last_daily_combo_ids:
			repeat_candidates.append(cid)
		else:
			fresh_candidates.append(cid)

	var ordered_candidates: Array[String] = []
	if not fresh_candidates.is_empty():
		var start_idx := (current_day - 1) % fresh_candidates.size()
		for i in range(fresh_candidates.size()):
			ordered_candidates.append(fresh_candidates[(start_idx + i) % fresh_candidates.size()])
	if not repeat_candidates.is_empty():
		var r_idx := current_day % repeat_candidates.size()
		for i in range(repeat_candidates.size()):
			ordered_candidates.append(repeat_candidates[(r_idx + i) % repeat_candidates.size()])

	var used_categories: Dictionary = {String(objectives[0].get("category", "")): true}
	var desired_total := 4 if eligible.size() >= 3 else mini(3, 1 + eligible.size())

	# First pass: prefer distinct categories for variety
	for cid in ordered_candidates:
		if objectives.size() >= desired_total:
			break
		var cand := _build_daily_candidate(cid, current_day, profile, false)
		var cat := String(cand.get("category", ""))
		if not used_categories.has(cat):
			used_categories[cat] = true
			objectives.append(cand)

	# Second pass: fill up to 3-4 objectives if needed
	for cid in ordered_candidates:
		if objectives.size() >= desired_total:
			break
		var already := false
		for o in objectives:
			if o["id"] == cid:
				already = true
				break
		if not already:
			objectives.append(_build_daily_candidate(cid, current_day, profile, false))

	last_daily_combo_ids.clear()
	for o in objectives:
		last_daily_combo_ids.append(String(o["id"]))
	objectives_updated.emit()

func generate_weekly_objectives(week_idx: int) -> void:
	current_week = maxi(1, week_idx)
	weekly_objectives.clear()
	var profile := _get_accessibility_profile()
	var has_garage: bool = bool(profile.get("has_garage", false))
	var has_hutieu: bool = bool(profile.get("has_hutieu", false))
	var max_biz_lvl: int = int(profile.get("max_business_level", 1))
	var house_lvl: int = int(profile.get("house_level", 1))
	var plot_count: int = int(profile.get("plot_count", 0))

	if has_garage or has_hutieu:
		var cust_target := 12 + (max_biz_lvl - 1) * 4
		var biz_hint := "Tiệm Sửa Xe hoặc Quán Hủ Tiếu"
		if has_garage and not has_hutieu:
			biz_hint = "Tiệm Sửa Xe"
		elif has_hutieu and not has_garage:
			biz_hint = "Quán Hủ Tiếu"
		weekly_objectives.append({
			"id": "wk_serve_customers",
			"title": "Tuần Lễ Phục Vụ",
			"desc": "Phục vụ %d khách tại %s" % [cust_target, biz_hint],
			"target": cust_target,
			"current": 0,
			"reward": 30000,
			"is_completed": false,
			"claimed": false
		})

	if bool(profile.get("has_garden", false)):
		var harvest_target := 8 + maxi(0, plot_count - 2) * 2
		weekly_objectives.append({
			"id": "wk_harvest_produce",
			"title": "Thu Hoạch Sân Vườn",
			"desc": "Thu hoạch %d nông sản từ vườn rau" % harvest_target,
			"target": harvest_target,
			"current": 0,
			"reward": 25000,
			"is_completed": false,
			"claimed": false
		})

	if has_garage or has_hutieu or bool(profile.get("has_garden", false)):
		var earn_target := 300000 + (house_lvl - 1) * 100000 + (max_biz_lvl - 1) * 50000
		weekly_objectives.append({
			"id": "wk_earn_money",
			"title": "Tích Lũy Tuần",
			"desc": "Kiếm %s từ kinh doanh và nông sản" % HouseholdWallet.format_money(earn_target),
			"target": earn_target,
			"current": 0,
			"reward": 40000,
			"is_completed": false,
			"claimed": false
		})

	if has_garage or has_hutieu:
		if not bool(profile.get("all_business_upgrades_owned", false)) or max_biz_lvl < 5:
			weekly_objectives.append({
				"id": "wk_improve_business",
				"title": "Phát Triển Cửa Hàng",
				"desc": "Mua 1 nâng cấp thiết bị hoặc tăng hạng cửa hàng",
				"target": 1,
				"current": 0,
				"reward": 35000,
				"is_completed": false,
				"claimed": false
			})
		else:
			weekly_objectives.append({
				"id": "wk_vip_customers",
				"title": "Đón Khách Thượng Lưu",
				"desc": "Phục vụ 2 khách VIP trong tuần",
				"target": 2,
				"current": 0,
				"reward": 35000,
				"is_completed": false,
				"claimed": false
			})

	if bool(profile.get("has_pet", false)):
		weekly_objectives.append({
			"id": "wk_pet_care",
			"title": "Bạn Thân Của Miu Miu",
			"desc": "Thực hiện 5 lần chăm sóc mèo cưng",
			"target": 5,
			"current": 0,
			"reward": 20000,
			"is_completed": false,
			"claimed": false
		})

	objectives_updated.emit()

func _ensure_milestones_initialized() -> void:
	if milestones.is_empty():
		for def in MILESTONE_DEFINITIONS:
			var entry := def.duplicate(true)
			entry["is_completed"] = false
			entry["claimed"] = false
			entry["completed_day"] = 0
			milestones.append(entry)
	else:
		# Ensure any newly added milestone definitions exist on older saves
		var existing_ids: Dictionary = {}
		for m in milestones:
			existing_ids[m.get("id", "")] = true
		for def in MILESTONE_DEFINITIONS:
			if not existing_ids.has(def["id"]):
				var entry := def.duplicate(true)
				entry["is_completed"] = false
				entry["claimed"] = false
				entry["completed_day"] = 0
				milestones.append(entry)

func _on_day_started(day_number: int) -> void:
	var new_week := get_week_for_day(day_number)
	var week_changed := new_week != current_week
	if week_changed:
		generate_weekly_objectives(new_week)
	if day_number != current_day or objectives.is_empty():
		generate_daily_objectives(day_number)
	call_deferred("_save_progress")
	if is_inside_tree():
		var garden_mgr := get_tree().get_first_node_in_group("garden_manager") as GardenManager
		if is_instance_valid(garden_mgr):
			for plot in garden_mgr.plots:
				_connect_plot_signals(plot)

func record_customer_served() -> void:
	advance_progress("obj_serve_customers", 1, false)
	advance_weekly_progress("wk_serve_customers", 1, false)
	_save_progress()

func record_revenue(amount: int) -> void:
	advance_progress("obj_daily_revenue", amount, false)
	advance_weekly_progress("wk_earn_money", amount, false)
	_save_progress()

func record_pet_care() -> void:
	advance_progress("obj_care_pet", 1, false)
	advance_weekly_progress("wk_pet_care", 1, false)
	_save_progress()

func record_crop_watered() -> void:
	advance_progress("obj_water_crops", 1)

func record_crop_harvested(qty: int = 1) -> void:
	advance_progress("obj_harvest_produce", 1, false)
	advance_weekly_progress("wk_harvest_produce", maxi(1, qty), false)
	unlock_milestone("ms_first_harvest", false)
	_save_progress()

func advance_progress(obj_id: String, amount: int = 1, persist: bool = true) -> void:
	if amount <= 0:
		return
	for obj in objectives:
		if obj["id"] == obj_id and not obj["is_completed"]:
			obj["current"] = mini(int(obj["target"]), int(obj["current"]) + amount)
			if obj["current"] >= obj["target"]:
				_complete_objective(obj)
			objectives_updated.emit()
			if persist:
				_save_progress()
			break

func advance_weekly_progress(wk_id: String, amount: int = 1, persist: bool = true) -> void:
	if amount <= 0:
		return
	for wk in weekly_objectives:
		if wk["id"] == wk_id and not wk.get("is_completed", false):
			wk["current"] = mini(int(wk["target"]), int(wk["current"]) + amount)
			if wk["current"] >= wk["target"]:
				_complete_weekly_objective(wk)
			objectives_updated.emit()
			if persist:
				_save_progress()
			break

func _complete_objective(obj: Dictionary) -> void:
	if obj.get("is_completed", false) or obj.get("claimed", false):
		return
	obj["is_completed"] = true
	obj["claimed"] = true
	completed_count += 1
	var reward: int = int(obj.get("reward", 0))
	var house_mgr := get_tree().get_first_node_in_group("house_progression_manager") as HouseProgressionManager if is_inside_tree() else null
	if is_instance_valid(house_mgr) and reward > 0:
		var cozy_pct := house_mgr.get_cozy_objective_bonus_pct()
		if cozy_pct > 0.0:
			reward = int(round(float(reward) * (1.0 + cozy_pct)))

	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if is_instance_valid(econ) and is_instance_valid(econ.wallet) and reward > 0:
		var tx_id := "objective_%s_day_%d" % [obj["id"], current_day]
		econ.wallet.deposit(reward, "objective", "Thưởng mục tiêu ngày: %s" % obj["title"], tx_id)

	var fx = get_tree().get_first_node_in_group("chaos_feedback") if is_inside_tree() else null
	if is_instance_valid(fx) and fx.has_method("show_toast"):
		fx.show_toast("🎯 Hoàn thành mục tiêu: %s! Nhận thưởng +%s! ✨" % [
			obj["title"], HouseholdWallet.format_money(reward)
		])

	objective_completed.emit(obj["id"], reward)
	if completed_count >= objectives.size():
		all_objectives_completed.emit()

func _complete_weekly_objective(wk: Dictionary) -> void:
	if wk.get("is_completed", false) or wk.get("claimed", false):
		return
	wk["is_completed"] = true
	wk["claimed"] = true
	var reward: int = int(wk.get("reward", 0))

	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if is_instance_valid(econ) and is_instance_valid(econ.wallet) and reward > 0:
		var tx_id := "weekly_%s_week_%d" % [wk["id"], current_week]
		econ.wallet.deposit(reward, "weekly_objective", "Thưởng mục tiêu tuần %d: %s" % [current_week, wk["title"]], tx_id)

	var fx = get_tree().get_first_node_in_group("chaos_feedback") if is_inside_tree() else null
	if is_instance_valid(fx) and fx.has_method("show_toast"):
		fx.show_toast("📅 Hoàn thành mục tiêu tuần: %s! (+%s)" % [
			wk["title"], HouseholdWallet.format_money(reward)
		])

	weekly_objective_completed.emit(wk["id"], reward)

func unlock_milestone(milestone_id: String, persist: bool = true) -> bool:
	_ensure_milestones_initialized()
	for ms in milestones:
		if ms.get("id", "") == milestone_id:
			if ms.get("is_completed", false) or ms.get("claimed", false):
				return false
			ms["is_completed"] = true
			ms["claimed"] = true
			ms["completed_day"] = current_day
			var reward: int = int(ms.get("reward", 0))
			var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
			if is_instance_valid(econ) and is_instance_valid(econ.wallet) and reward > 0:
				var tx_id := "milestone_%s" % milestone_id
				econ.wallet.deposit(reward, "milestone", "Thành tựu: %s" % ms["title"], tx_id)

			var fx = get_tree().get_first_node_in_group("chaos_feedback") if is_inside_tree() else null
			if is_instance_valid(fx) and fx.has_method("show_toast"):
				fx.show_toast("🏆 Thành tựu mới: %s! (+%s)" % [
					ms["title"], HouseholdWallet.format_money(reward)
				])

			milestone_unlocked.emit(milestone_id, reward)
			objectives_updated.emit()
			if persist:
				_save_progress()
			return true
	return false

func has_completed_any_objective() -> bool:
	return completed_count > 0

func get_summary_list() -> Array:
	return objectives.duplicate(true)

func get_weekly_summary() -> Dictionary:
	var done := 0
	for wk in weekly_objectives:
		if wk.get("is_completed", false):
			done += 1
	return {
		"week": current_week,
		"day_in_week": get_day_in_week(current_day),
		"completed": done,
		"total": weekly_objectives.size(),
		"objectives": weekly_objectives.duplicate(true)
	}

func get_milestone_summary() -> Dictionary:
	_ensure_milestones_initialized()
	var unlocked := 0
	var next_milestone: Dictionary = {}
	for ms in milestones:
		if ms.get("is_completed", false):
			unlocked += 1
		elif next_milestone.is_empty():
			next_milestone = ms.duplicate(true)
	return {
		"unlocked": unlocked,
		"total": milestones.size(),
		"next_milestone": next_milestone,
		"milestones": milestones.duplicate(true)
	}

# Signal callbacks
func _on_business_order_completed(order: BusinessOrder, reward: int) -> void:
	advance_progress("obj_serve_customers", 1, false)
	advance_progress("obj_daily_revenue", reward, false)
	advance_progress("obj_service_streak", 1, false)
	advance_weekly_progress("wk_serve_customers", 1, false)
	advance_weekly_progress("wk_earn_money", reward, false)
	if is_instance_valid(order):
		if order.service_type == "garage":
			unlock_milestone("ms_first_repair", false)
		elif order.service_type == "hutieu":
			unlock_milestone("ms_first_noodle", false)
		if order.customer_type == BusinessOrder.CustomerType.VIP:
			unlock_milestone("ms_first_vip", false)
			advance_weekly_progress("wk_vip_customers", 1, false)
	call_deferred("_save_progress")

func _on_business_level_up(new_level: int) -> void:
	advance_weekly_progress("wk_improve_business", 1, false)
	if new_level >= 3:
		unlock_milestone("ms_business_lvl_3", false)
	call_deferred("_save_progress")

func _on_house_upgraded(new_level: int, _unlocked_areas: Array) -> void:
	if new_level >= 2:
		unlock_milestone("ms_first_house_upgrade")

func _on_purchase_completed(product: EconomyProduct, _count: int, _cost: int) -> void:
	if not is_instance_valid(product):
		return
	if product.category == "furniture" or product.id.begins_with("furn_"):
		advance_progress("obj_furniture")
	elif product.category in ["supplies", "ingredient", "seed", "tool"] or product.id.begins_with("repair_kit") or product.id.begins_with("seed_"):
		advance_progress("obj_buy_supplies")
	elif product.category == "upgrade" and (product.id.begins_with("upg_garage_") or product.id.begins_with("upg_hutieu_")):
		advance_weekly_progress("wk_improve_business", 1)

func _on_furniture_placed(_furniture_id: String, _node: Node3D) -> void:
	advance_progress("obj_furniture")

func _on_pet_action(_action: String, _pet_node: Node = null) -> void:
	record_pet_care()

func _on_crop_planted(_plot_id: String, _crop_id: String) -> void:
	advance_progress("obj_plant_crops")

func _on_crop_watered(_plot_id: String) -> void:
	record_crop_watered()

func _on_crop_harvested(_plot_id: String, _crop_id: String, qty: int) -> void:
	record_crop_harvested(qty)

func _on_produce_sold(_product: EconomyProduct, _count: int, earnings: int) -> void:
	record_revenue(earnings)

func _on_npc_interaction_started(npc: Node, _player: Node3D) -> void:
	var npc_id := String(npc.data.id) if is_instance_valid(npc) and "data" in npc and npc.data else "neighbor"
	neighbor_interactions[npc_id] = int(neighbor_interactions.get(npc_id, 0)) + 1
	var total := 0
	for k in neighbor_interactions:
		total += int(neighbor_interactions[k])
	if int(neighbor_interactions[npc_id]) >= 3 or total >= 3:
		unlock_milestone("ms_close_neighbor")
	else:
		_save_progress()

func _on_wallet_balance_changed(_new_balance: int, _delta: int) -> void:
	_refresh_hud()
	_refresh_progression_panel()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ObjectiveHUD"
	layer.layer = 5
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 152)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("141a21", 0.72)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 2
	sb.border_color = Color("ffd54f", 0.65)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	objective_label = Label.new()
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.add_theme_font_size_override("font_size", 12)
	objective_label.add_theme_color_override("font_color", Color("fff4dc"))
	objective_label.add_theme_color_override("font_shadow_color", Color("14100a"))
	objective_label.add_theme_constant_override("shadow_offset_x", 1)
	objective_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(objective_label)

	hud_toggle_button = Button.new()
	hud_toggle_button.text = "📊 Tiến độ Tuần & Thành tựu (J)"
	hud_toggle_button.flat = true
	hud_toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_toggle_button.add_theme_font_size_override("font_size", 11)
	hud_toggle_button.add_theme_color_override("font_color", Color("80d8ff"))
	hud_toggle_button.pressed.connect(toggle_progression_panel)
	vbox.add_child(hud_toggle_button)

func _build_progression_panel() -> void:
	progression_layer = CanvasLayer.new()
	progression_layer.name = "ProgressionPanelLayer"
	progression_layer.layer = 95
	progression_layer.visible = false
	add_child(progression_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.08, 0.11, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progression_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progression_layer.add_child(center)

	progression_panel = PanelContainer.new()
	progression_panel.custom_minimum_size = Vector2(540, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e2730")
	style.border_color = Color("ffd54f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	progression_panel.add_theme_stylebox_override("panel", style)
	center.add_child(progression_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	progression_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	progression_title_label = Label.new()
	progression_title_label.text = "📊 TIẾN ĐỘ PHÁT TRIỂN"
	progression_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression_title_label.add_theme_font_size_override("font_size", 19)
	progression_title_label.add_theme_color_override("font_color", Color("ffd54f"))
	header.add_child(progression_title_label)

	var close_btn := Button.new()
	close_btn.text = "Đóng (J / ESC)"
	close_btn.pressed.connect(func(): set_progression_panel_visible(false))
	header.add_child(close_btn)

	progression_subtitle_label = Label.new()
	progression_subtitle_label.add_theme_font_size_override("font_size", 12)
	progression_subtitle_label.add_theme_color_override("font_color", Color("b0bec5"))
	vbox.add_child(progression_subtitle_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)

	tab_daily_btn = Button.new()
	tab_daily_btn.text = "📋 Hôm Nay"
	tab_daily_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_daily_btn.pressed.connect(func(): _select_tab("daily"))
	tabs.add_child(tab_daily_btn)

	tab_weekly_btn = Button.new()
	tab_weekly_btn.text = "📅 Tuần Này"
	tab_weekly_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_weekly_btn.pressed.connect(func(): _select_tab("weekly"))
	tabs.add_child(tab_weekly_btn)

	tab_milestone_btn = Button.new()
	tab_milestone_btn.text = "🏆 Thành Tựu"
	tab_milestone_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_milestone_btn.pressed.connect(func(): _select_tab("milestones"))
	tabs.add_child(tab_milestone_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 270)
	vbox.add_child(scroll)

	progression_list_container = VBoxContainer.new()
	progression_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(progression_list_container)

func _select_tab(tab_name: String) -> void:
	active_tab = tab_name
	_refresh_progression_panel()

func toggle_progression_panel() -> void:
	if is_instance_valid(progression_layer):
		set_progression_panel_visible(not progression_layer.visible)

func set_progression_panel_visible(show_panel: bool) -> void:
	if not is_instance_valid(progression_layer):
		return
	progression_layer.visible = show_panel
	if show_panel:
		_refresh_progression_panel()

func _refresh_progression_panel() -> void:
	if not is_instance_valid(progression_list_container) or not is_instance_valid(progression_layer):
		return
	for child in progression_list_container.get_children():
		child.queue_free()

	var day_in_wk := get_day_in_week(current_day)
	var ms_sum := get_milestone_summary()
	var wk_sum := get_weekly_summary()
	progression_subtitle_label.text = "Ngày %d (Tuần %d — Ngày %d/7) · Tuần: %d/%d · Thành tựu: %d/%d" % [
		current_day, current_week, day_in_wk,
		int(wk_sum["completed"]), int(wk_sum["total"]),
		int(ms_sum["unlocked"]), int(ms_sum["total"])
	]

	if active_tab == "daily":
		for obj in objectives:
			var done := bool(obj.get("is_completed", false))
			var prefix := "✅" if done else ("★" if bool(obj.get("is_primary", false)) else "○")
			var dest := String(obj.get("destination", ""))
			var right_text := "%d/%d · +%s" % [int(obj.get("current", 0)), int(obj.get("target", 1)), HouseholdWallet.format_money(int(obj.get("reward", 0)))]
			var sub := String(obj.get("desc", ""))
			if dest != "":
				sub += " (📍 %s)" % dest
			_add_progression_row("%s %s" % [prefix, obj.get("title", "")], sub, right_text, done)
	elif active_tab == "weekly":
		for wk in weekly_objectives:
			var done := bool(wk.get("is_completed", false))
			var prefix := "✅" if done else "📅"
			var right_text := "%s/%s · +%s" % [
				_format_progress_value(wk.get("id", ""), int(wk.get("current", 0))),
				_format_progress_value(wk.get("id", ""), int(wk.get("target", 1))),
				HouseholdWallet.format_money(int(wk.get("reward", 0)))
			]
			_add_progression_row("%s %s" % [prefix, wk.get("title", "")], String(wk.get("desc", "")), right_text, done)
	else:
		_ensure_milestones_initialized()
		for ms in milestones:
			var done := bool(ms.get("is_completed", false))
			var prefix := "🏆" if done else "🔒"
			var status_str := "Đã mở (Ngày %d)" % int(ms.get("completed_day", 0)) if done else "Yêu cầu: %s" % String(ms.get("unlock_req", ""))
			var sub := "%s\n%s · Phần thưởng: %s" % [String(ms.get("desc", "")), status_str, String(ms.get("unlock_text", ""))]
			var right_text := "+%s" % HouseholdWallet.format_money(int(ms.get("reward", 0)))
			_add_progression_row("%s %s" % [prefix, ms.get("title", "")], sub, right_text, done)

func _format_progress_value(id: String, val: int) -> String:
	if id == "wk_earn_money" or id == "obj_daily_revenue":
		return HouseholdWallet.format_money(val)
	return str(val)

func _add_progression_row(title_text: String, desc_text: String, right_text: String, is_done: bool) -> void:
	var row := PanelContainer.new()
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color("26362c") if is_done else Color("27323d")
	r_style.set_corner_radius_all(8)
	r_style.content_margin_left = 10
	r_style.content_margin_right = 10
	r_style.content_margin_top = 8
	r_style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", r_style)

	var hbox := HBoxContainer.new()
	row.add_child(hbox)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	var t_lbl := Label.new()
	t_lbl.text = title_text
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", Color("a5d6a7") if is_done else Color("fff3cf"))
	left.add_child(t_lbl)

	var d_lbl := Label.new()
	d_lbl.text = desc_text
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.add_theme_font_size_override("font_size", 12)
	d_lbl.add_theme_color_override("font_color", Color("cfd8dc"))
	left.add_child(d_lbl)

	var r_lbl := Label.new()
	r_lbl.text = right_text
	r_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r_lbl.add_theme_font_size_override("font_size", 13)
	r_lbl.add_theme_color_override("font_color", Color("69f0ae") if is_done else Color("ffd54f"))
	hbox.add_child(r_lbl)

	progression_list_container.add_child(row)

func _refresh_hud() -> void:
	if not is_instance_valid(objective_label):
		return
	var primary_lines := PackedStringArray()
	var optional_lines := PackedStringArray()
	for obj in objectives:
		var done := bool(obj.get("is_completed", false))
		var marker := "✓" if done else "○"
		var reward_str := HouseholdWallet.format_money(int(obj.get("reward", 0)))
		var prog := "%d/%d" % [int(obj.get("current", 0)), int(obj.get("target", 1))]
		if bool(obj.get("is_primary", false)) and primary_lines.is_empty():
			var dest := String(obj.get("destination", ""))
			var dest_str := (" · 📍 %s" % dest) if dest != "" else ""
			primary_lines.append("★ Đề xuất: %s (%s) · +%s%s" % [obj.get("title", ""), prog, reward_str, dest_str])
		elif optional_lines.size() < 3:
			optional_lines.append("%s %s (%s) · +%s" % [marker, obj.get("title", ""), prog, reward_str])

	var lines := PackedStringArray(["📋 NGÀY %d · TUẦN %d (%d/7)" % [current_day, current_week, get_day_in_week(current_day)]])
	for l in primary_lines:
		lines.append(l)
	for l in optional_lines:
		lines.append(l)

	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if is_instance_valid(econ) and econ.has_method("get_next_meaningful_goal"):
		var goal := econ.get_next_meaningful_goal()
		if int(goal.get("target_cost", 0)) > 0:
			var g_pct := int(goal.get("progress_pct", 0))
			var ready := " ✅" if bool(goal.get("ready_to_buy", false)) else ""
			lines.append("🚀 Tiếp theo: %s (%d%%)%s" % [goal.get("title", ""), g_pct, ready])
		else:
			lines.append("🚀 Tiếp theo: %s" % goal.get("title", ""))
	objective_label.text = "\n".join(lines)

func _save_progress() -> void:
	if not is_inside_tree():
		return
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()

# -----------------------------------------------------------------
# Persistence
# -----------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"day": current_day,
		"objectives": objectives.duplicate(true),
		"completed_count": completed_count,
		"last_daily_combo_ids": last_daily_combo_ids.duplicate(),
		"week_index": current_week,
		"weekly_objectives": weekly_objectives.duplicate(true),
		"milestones": milestones.duplicate(true),
		"neighbor_interactions": neighbor_interactions.duplicate(true)
	}

func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	current_day = maxi(1, int(data.get("day", current_day)))
	if data.has("last_daily_combo_ids") and data["last_daily_combo_ids"] is Array:
		last_daily_combo_ids.clear()
		for item in data["last_daily_combo_ids"]:
			last_daily_combo_ids.append(String(item))

	if data.has("neighbor_interactions") and data["neighbor_interactions"] is Dictionary:
		neighbor_interactions = data["neighbor_interactions"].duplicate(true)

	# Restore permanent milestones (never reset)
	_ensure_milestones_initialized()
	if data.has("milestones") and data["milestones"] is Array:
		var saved_ms_by_id: Dictionary = {}
		for entry in data["milestones"]:
			if entry is Dictionary and entry.has("id"):
				saved_ms_by_id[String(entry["id"])] = entry
		for ms in milestones:
			var mid := String(ms["id"])
			if saved_ms_by_id.has(mid):
				var saved_ms: Dictionary = saved_ms_by_id[mid]
				ms["is_completed"] = bool(saved_ms.get("is_completed", false))
				ms["claimed"] = bool(saved_ms.get("claimed", ms["is_completed"]))
				ms["completed_day"] = int(saved_ms.get("completed_day", 0))

	# Restore weekly objectives if still in the same 7-day cycle; otherwise roll new week
	var expected_week := get_week_for_day(current_day)
	var saved_week := int(data.get("week_index", expected_week))
	if saved_week == expected_week and data.has("weekly_objectives") and data["weekly_objectives"] is Array and not (data["weekly_objectives"] as Array).is_empty():
		current_week = saved_week
		weekly_objectives.clear()
		for entry in data["weekly_objectives"]:
			if entry is Dictionary:
				weekly_objectives.append(entry.duplicate(true))
	else:
		generate_weekly_objectives(expected_week)

	# Restore daily objectives
	if data.has("objectives") and data["objectives"] is Array and not (data["objectives"] as Array).is_empty():
		objectives.clear()
		for entry in data["objectives"]:
			if entry is Dictionary:
				objectives.append(entry.duplicate(true))
		completed_count = int(data.get("completed_count", 0))
		objectives_updated.emit()
	else:
		generate_daily_objectives(current_day)
