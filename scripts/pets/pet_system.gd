class_name PetSystem
extends RefCounted
## Manages Miu Miu, optional cozy pet care, toys/beds/accessories, unlocked behaviors, and one-time collection rewards.

signal pets_changed()
signal pet_discovered_gift(gift: Dictionary)

var pet_cfg: Dictionary = {}
var items_by_id: Dictionary = {}
var item_ids_sorted: Array[String] = []
var behaviors_by_id: Dictionary = {}
var behavior_ids_sorted: Array[String] = []
var milestones_by_id: Dictionary = {}
var milestone_ids_sorted: Array[String] = []

# Persistent state
var mood: String = "happy" # "idle" | "happy" | "sleep" (never sad/punishing)
var equipped_accessory: String = ""
var active_bed: String = ""
var owned_items: Dictionary = {}
var unlocked_behaviors: Dictionary = {}
var claimed_milestones: Dictionary = {}
var interactions_count: int = 0
var last_reaction: String = ""
var last_gift_unix: int = 0

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)
	reset()

func apply_config(cfg: Dictionary) -> void:
	pet_cfg = (cfg.get("pet", {}) as Dictionary).duplicate(true)

	items_by_id.clear()
	item_ids_sorted.clear()
	var raw_items: Variant = cfg.get("items", [])
	if typeof(raw_items) == TYPE_ARRAY:
		for entry in (raw_items as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var it := (entry as Dictionary).duplicate(true)
			var iid := String(it.get("id", ""))
			if iid != "":
				items_by_id[iid] = it
				item_ids_sorted.append(iid)

	behaviors_by_id.clear()
	behavior_ids_sorted.clear()
	var raw_beh: Variant = cfg.get("behaviors", [])
	if typeof(raw_beh) == TYPE_ARRAY:
		for entry in (raw_beh as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var b := (entry as Dictionary).duplicate(true)
			var bid := String(b.get("id", ""))
			if bid != "":
				behaviors_by_id[bid] = b
				behavior_ids_sorted.append(bid)

	milestones_by_id.clear()
	milestone_ids_sorted.clear()
	var raw_ms: Variant = cfg.get("milestones", [])
	if typeof(raw_ms) == TYPE_ARRAY:
		for entry in (raw_ms as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var m := (entry as Dictionary).duplicate(true)
			var mid := String(m.get("id", ""))
			if mid != "":
				milestones_by_id[mid] = m
				milestone_ids_sorted.append(mid)

func reset() -> void:
	mood = "happy"
	equipped_accessory = ""
	active_bed = ""
	owned_items.clear()
	unlocked_behaviors.clear()
	claimed_milestones.clear()
	interactions_count = 0
	last_gift_unix = 0
	last_reaction = "Miu Miu đang vẫy đuôi chào Boy & Girl!"
	_sync_unlocked_behaviors()
	pets_changed.emit()

func _sync_unlocked_behaviors() -> void:
	for bid: String in behavior_ids_sorted:
		var b := behaviors_by_id[bid] as Dictionary
		var req := String(b.get("unlocked_by", ""))
		if req == "" or owned_items.has(req):
			unlocked_behaviors[bid] = true

func is_item_owned(item_id: String) -> bool:
	return owned_items.has(item_id)

func get_owned_count() -> int:
	return owned_items.size()

func is_behavior_unlocked(behavior_id: String) -> bool:
	return unlocked_behaviors.has(behavior_id)

func is_milestone_claimed(milestone_id: String) -> bool:
	return claimed_milestones.has(milestone_id)

func can_claim_milestone(milestone_id: String) -> bool:
	if not milestones_by_id.has(milestone_id) or claimed_milestones.has(milestone_id):
		return false
	var m := milestones_by_id[milestone_id] as Dictionary
	return owned_items.size() >= int(m.get("required_items", 999))

func buy_item(item_id: String, wallet: Wallet) -> Dictionary:
	if not items_by_id.has(item_id):
		return {"ok": false, "reason": "Món đồ thú cưng không tồn tại."}
	if owned_items.has(item_id):
		return {"ok": false, "reason": "Bạn đã sở hữu món này cho Miu Miu rồi."}
	var cfg := items_by_id[item_id] as Dictionary
	var cost := maxi(0, int(cfg.get("cost", 0)))
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}

	owned_items[item_id] = true
	var cat := String(cfg.get("category", ""))
	if cat == "accessory" and equipped_accessory == "":
		equipped_accessory = item_id
	elif cat == "bed" and active_bed == "":
		active_bed = item_id

	_sync_unlocked_behaviors()
	mood = "happy"
	last_reaction = "Miu Miu thích thú ngửi %s mới!" % String(cfg.get("display_name", item_id))
	pets_changed.emit()
	return {"ok": true, "cost": cost, "item_id": item_id}

func equip_item(item_id: String) -> Dictionary:
	if not owned_items.has(item_id) or not items_by_id.has(item_id):
		return {"ok": false, "reason": "Chưa sở hữu món này."}
	var cfg := items_by_id[item_id] as Dictionary
	var cat := String(cfg.get("category", ""))
	if cat == "accessory":
		equipped_accessory = "" if equipped_accessory == item_id else item_id
	elif cat == "bed":
		active_bed = "" if active_bed == item_id else item_id
	else:
		last_reaction = "Miu Miu đang chơi cùng %s!" % String(cfg.get("display_name", item_id))
		mood = "happy"
		pets_changed.emit()
		return {"ok": true, "equipped": false}
	last_reaction = "Miu Miu đã thử %s!" % String(cfg.get("display_name", item_id))
	pets_changed.emit()
	return {"ok": true, "equipped": true}

func get_home_context_text(home: HomeSystem) -> String:
	if home == null:
		return "Miu Miu đang thư giãn trong nhà."
	var rid := home.active_room_id
	var r_cfg := home.rooms_by_id.get(rid, {}) as Dictionary
	var r_name := String(r_cfg.get("display_name", rid))
	if not home.is_room_unlocked(rid):
		return "Miu Miu đang ngó vào %s (chưa mở khóa)." % r_name

	var slots := home.get_room_slots(rid)
	for placed: String in slots:
		if placed != "" and home.items_by_id.has(placed):
			var f_cfg := home.items_by_id[placed] as Dictionary
			return "Miu Miu đang nằm chill cạnh %s ở %s." % [String(f_cfg.get("display_name", placed)), r_name]
	if active_bed != "" and items_by_id.has(active_bed):
		var b_cfg := items_by_id[active_bed] as Dictionary
		return "Miu Miu đang cuộn tròn trên %s tại %s." % [String(b_cfg.get("display_name", active_bed)), r_name]
	return "Miu Miu đang đi dạo quanh %s." % r_name

func pet_miu_miu(home: HomeSystem = null) -> Dictionary:
	interactions_count += 1
	mood = "happy"
	var actor := home.get_character_label() if home != null else "Bạn"
	var unlocked_list: Array[String] = []
	for bid: String in behavior_ids_sorted:
		if unlocked_behaviors.has(bid):
			unlocked_list.append(bid)
	var chosen_text := "Miu Miu kêu gừ gừ ấm áp."
	if not unlocked_list.is_empty():
		var idx := (interactions_count - 1) % unlocked_list.size()
		var b_cfg := behaviors_by_id[unlocked_list[idx]] as Dictionary
		chosen_text = String(b_cfg.get("text", chosen_text))
	last_reaction = "%s vuốt ve Miu Miu: %s" % [actor, chosen_text]
	pets_changed.emit()
	return {"ok": true, "text": last_reaction, "count": interactions_count}

func play_with_miu_miu(home: HomeSystem = null) -> Dictionary:
	interactions_count += 1
	mood = "happy"
	var actor := home.get_character_label() if home != null else "Bạn"
	var toys: Array[String] = []
	for iid: String in item_ids_sorted:
		if owned_items.has(iid):
			var it := items_by_id[iid] as Dictionary
			if String(it.get("category", "")) == "toy":
				toys.append(String(it.get("display_name", iid)))
	if toys.is_empty():
		last_reaction = "%s chơi trốn tìm nhẹ nhàng cùng Miu Miu!" % actor
	else:
		var t_name := toys[(interactions_count - 1) % toys.size()]
		last_reaction = "%s dùng %s chơi cùng Miu Miu — Miu Miu nhảy cẫng thích thú!" % [actor, t_name]
	pets_changed.emit()
	return {"ok": true, "text": last_reaction, "count": interactions_count}

func feed_miu_miu(inventory: Inventory, crop_id: String = "carrot") -> Dictionary:
	if inventory == null:
		return {"ok": false, "reason": "Không tìm thấy kho đồ."}
	if inventory.get_count(crop_id) < 1:
		return {"ok": false, "reason": "Kho không có %s — không sao cả, Miu Miu vẫn vui!" % crop_id}
	if not inventory.remove_item(crop_id, 1):
		return {"ok": false, "reason": "Không thể lấy %s từ kho." % crop_id}
	interactions_count += 1
	mood = "sleep"
	last_reaction = "Miu Miu nhấm nháp %s ngon lành rồi lim dim ngủ!" % crop_id
	pets_changed.emit()
	return {"ok": true, "text": last_reaction, "consumed": crop_id}

func maybe_discover_gift(clock: GameClock, wallet: Wallet, inventory: Inventory, unlocked_crops: Array[String]) -> Dictionary:
	if interactions_count <= 0 or (interactions_count % 3) != 0:
		return {"ok": false}
	var now_u := clock.now() if clock != null else 0
	if clock != null and last_gift_unix > 0 and (now_u - last_gift_unix) < 30:
		return {"ok": false}
	last_gift_unix = now_u
	var gift := {}
	if not unlocked_crops.is_empty() and inventory != null and inventory.can_add(1) and (interactions_count % 2 == 1):
		var cid := unlocked_crops[interactions_count % unlocked_crops.size()]
		inventory.add_item(cid, 1)
		gift = {"ok": true, "kind": "item", "item_id": cid, "amount": 1, "text": "🎁 Miu Miu tha về 1 %s từ ngoài vườn!" % cid}
	else:
		var bonus := 8
		if wallet != null:
			wallet.earn(bonus)
		gift = {"ok": true, "kind": "coins", "coins": bonus, "text": "🎁 Miu Miu khều dưới ghế tìm thấy +%d xu!" % bonus}
	last_reaction = String(gift["text"])
	pet_discovered_gift.emit(gift)
	pets_changed.emit()
	return gift

func react_to_activity(activity: String) -> String:
	match activity:
		"harvest":
			last_reaction = "Miu Miu ngửi ngửi rổ rau vừa thu hoạch!"
		"cook":
			last_reaction = "Miu Miu ngóng mũi về phía nồi Hủ Tiếu thơm phức!"
		"delivery":
			last_reaction = "Miu Miu vẫy đuôi tiễn xe Ga-ra lên đường!"
		"upgrade":
			last_reaction = "Miu Miu chạy quanh kiểm tra góc nhà mới nâng cấp!"
		_:
			last_reaction = "Miu Miu kêu meo nhẹ đầy hứng khởi."
	pets_changed.emit()
	return last_reaction

func claim_milestone(milestone_id: String, wallet: Wallet, progression: ProgressionSystem) -> Dictionary:
	if not milestones_by_id.has(milestone_id):
		return {"ok": false, "reason": "Cột mốc không tồn tại."}
	if claimed_milestones.has(milestone_id):
		return {"ok": false, "reason": "Đã nhận thưởng cột mốc này rồi."}
	var m := milestones_by_id[milestone_id] as Dictionary
	var req := int(m.get("required_items", 999))
	if owned_items.size() < req:
		return {"ok": false, "reason": "Cần sưu tập ít nhất %d món đồ cho Miu Miu." % req}

	claimed_milestones[milestone_id] = true
	var r_coins := maxi(0, int(m.get("reward_coins", 0)))
	var r_xp := maxi(0, int(m.get("reward_xp", 0)))
	if r_coins > 0 and wallet != null:
		wallet.earn(r_coins)
	var lv_res := {}
	if r_xp > 0 and progression != null:
		lv_res = progression.add_xp(r_xp)
	last_reaction = "🎉 Hoàn thành bộ sưu tập '%s'!" % String(m.get("display_name", milestone_id))
	pets_changed.emit()
	return {
		"ok": true,
		"coins": r_coins,
		"xp": r_xp,
		"leveled_up": bool(lv_res.get("leveled_up", false)),
		"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
	}

func get_ascii_portrait() -> String:
	var key := "ascii_idle"
	if mood == "happy":
		key = "ascii_happy"
	elif mood == "sleep":
		key = "ascii_sleep"
	var base := String(pet_cfg.get(key, "=^._.^="))
	var extras: Array[String] = []
	if equipped_accessory != "" and items_by_id.has(equipped_accessory):
		var ac := items_by_id[equipped_accessory] as Dictionary
		extras.append("Phụ kiện: %s %s" % [String(ac.get("ascii", "")), String(ac.get("display_name", ""))])
	if active_bed != "" and items_by_id.has(active_bed):
		var bd := items_by_id[active_bed] as Dictionary
		extras.append("Chỗ nằm: %s %s" % [String(bd.get("ascii", "")), String(bd.get("display_name", ""))])
	if extras.is_empty():
		return base
	return base + "\n" + " | ".join(extras)

func to_dict() -> Dictionary:
	var owned_arr: Array[String] = []
	for iid: String in owned_items.keys():
		owned_arr.append(iid)
	var claimed_arr: Array[String] = []
	for mid: String in claimed_milestones.keys():
		claimed_arr.append(mid)
	return {
		"mood": mood,
		"equipped_accessory": equipped_accessory,
		"active_bed": active_bed,
		"owned_items": owned_arr,
		"claimed_milestones": claimed_arr,
		"interactions_count": interactions_count,
		"last_gift_unix": last_gift_unix,
		"last_reaction": last_reaction
	}

func load_from_dict(data: Dictionary) -> void:
	reset()
	var m := String(data.get("mood", "happy"))
	if m in ["idle", "happy", "sleep"]:
		mood = m
	var eq_acc := String(data.get("equipped_accessory", ""))
	var act_bed := String(data.get("active_bed", ""))

	var raw_owned: Variant = data.get("owned_items", [])
	if typeof(raw_owned) == TYPE_ARRAY:
		for v in (raw_owned as Array):
			var iid := String(v)
			if items_by_id.has(iid):
				owned_items[iid] = true

	if eq_acc != "" and owned_items.has(eq_acc):
		equipped_accessory = eq_acc
	if act_bed != "" and owned_items.has(act_bed):
		active_bed = act_bed

	var raw_claimed: Variant = data.get("claimed_milestones", [])
	if typeof(raw_claimed) == TYPE_ARRAY:
		for v in (raw_claimed as Array):
			var mid := String(v)
			if milestones_by_id.has(mid):
				claimed_milestones[mid] = true

	interactions_count = maxi(0, int(data.get("interactions_count", 0)))
	last_gift_unix = maxi(0, int(data.get("last_gift_unix", 0)))
	var lr := String(data.get("last_reaction", ""))
	if lr != "":
		last_reaction = lr
	_sync_unlocked_behaviors()
	pets_changed.emit()
