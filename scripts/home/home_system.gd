class_name HomeSystem
extends RefCounted
## Manages the shared Boy/Girl home, room unlocks, furniture collection & placement, and cozy moments.

signal home_changed()
signal character_reacted(character_id: String, text: String)

var rooms_by_id: Dictionary = {}
var room_ids_sorted: Array[String] = []
var items_by_id: Dictionary = {}
var item_ids_sorted: Array[String] = []
var interactions: Array[String] = []

# Persistent state
var active_character: String = "boy" # "boy" | "girl"
var active_room_id: String = "living_room"
var selected_furniture_id: String = ""
var unlocked_rooms: Dictionary = {}
var owned_furniture: Dictionary = {}
var placements: Dictionary = {} # room_id -> Array[String]
var cozy_moments_count: int = 0
var last_moment: String = ""
var last_coop_unix: int = 0

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)
	reset()

func apply_config(cfg: Dictionary) -> void:
	rooms_by_id.clear()
	room_ids_sorted.clear()
	var raw_rooms: Variant = cfg.get("rooms", [])
	if typeof(raw_rooms) == TYPE_ARRAY:
		for entry in (raw_rooms as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var r := (entry as Dictionary).duplicate(true)
			var rid := String(r.get("id", ""))
			if rid != "":
				rooms_by_id[rid] = r
				room_ids_sorted.append(rid)

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

	interactions.clear()
	var raw_int: Variant = cfg.get("interactions", [])
	if typeof(raw_int) == TYPE_ARRAY:
		for s in (raw_int as Array):
			interactions.append(String(s))

func reset() -> void:
	active_character = "boy"
	active_room_id = room_ids_sorted[0] if not room_ids_sorted.is_empty() else "living_room"
	selected_furniture_id = ""
	unlocked_rooms.clear()
	owned_furniture.clear()
	placements.clear()
	cozy_moments_count = 0
	last_moment = ""
	last_coop_unix = 0

	for rid in room_ids_sorted:
		var r := rooms_by_id[rid] as Dictionary
		var slots_cnt := maxi(1, int(r.get("slots", 4)))
		var arr: Array[String] = []
		for _i in range(slots_cnt):
			arr.append("")
		placements[rid] = arr
		if bool(r.get("unlocked_by_default", false)):
			unlocked_rooms[rid] = true
	home_changed.emit()

func switch_character() -> String:
	active_character = "girl" if active_character == "boy" else "boy"
	home_changed.emit()
	return active_character

func get_character_label() -> String:
	return "👦 Boy" if active_character == "boy" else "👧 Girl"

func is_room_unlocked(room_id: String) -> bool:
	return unlocked_rooms.has(room_id)

func is_furniture_owned(fid: String) -> bool:
	return owned_furniture.has(fid)

func get_owned_count() -> int:
	return owned_furniture.size()

func select_room(room_id: String) -> bool:
	if not rooms_by_id.has(room_id):
		return false
	active_room_id = room_id
	home_changed.emit()
	return true

func unlock_room(room_id: String, wallet: Wallet) -> Dictionary:
	if not rooms_by_id.has(room_id):
		return {"ok": false, "reason": "Phòng không tồn tại."}
	if unlocked_rooms.has(room_id):
		return {"ok": false, "reason": "Phòng này đã mở."}
	var r := rooms_by_id[room_id] as Dictionary
	var cost := maxi(0, int(r.get("unlock_cost", 100)))
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu mở phòng (cần %d xu)." % cost}
	unlocked_rooms[room_id] = true
	active_room_id = room_id
	home_changed.emit()
	return {"ok": true, "cost": cost, "display_name": String(r.get("display_name", room_id))}

func buy_furniture(fid: String, wallet: Wallet) -> Dictionary:
	if not items_by_id.has(fid):
		return {"ok": false, "reason": "Nội thất không tồn tại."}
	if owned_furniture.has(fid):
		return {"ok": false, "reason": "Bạn đã sở hữu món nội thất này rồi."}
	var it := items_by_id[fid] as Dictionary
	var cost := maxi(0, int(it.get("cost", 30)))
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu mua nội thất (cần %d xu)." % cost}
	owned_furniture[fid] = true
	selected_furniture_id = fid
	home_changed.emit()
	return {"ok": true, "cost": cost, "display_name": String(it.get("display_name", fid))}

func select_furniture(fid: String) -> bool:
	if fid != "" and not owned_furniture.has(fid):
		return false
	selected_furniture_id = fid
	home_changed.emit()
	return true

func place_furniture(room_id: String, slot_idx: int, fid: String) -> Dictionary:
	if not unlocked_rooms.has(room_id):
		return {"ok": false, "reason": "Phòng chưa mở khóa."}
	if fid != "" and not owned_furniture.has(fid):
		return {"ok": false, "reason": "Bạn chưa sở hữu món nội thất này."}
	var arr: Array = placements.get(room_id, []) as Array
	if slot_idx < 0 or slot_idx >= arr.size():
		return {"ok": false, "reason": "Vị trí đặt không hợp lệ."}
	arr[slot_idx] = fid
	placements[room_id] = arr
	home_changed.emit()
	return {"ok": true}

func get_room_slots(room_id: String) -> Array:
	return placements.get(room_id, []) as Array

func trigger_couple_moment() -> Dictionary:
	if interactions.is_empty():
		return {"ok": false, "reason": "Chưa có hoạt động đôi."}
	var text := interactions[cozy_moments_count % interactions.size()]
	cozy_moments_count += 1
	var actor := "Boy & Girl" if active_character == "boy" else "Girl & Boy"
	last_moment = "%s %s" % [actor, text]
	home_changed.emit()
	return {"ok": true, "text": last_moment, "count": cozy_moments_count}

func get_contextual_reaction(event_type: String, detail: String = "") -> String:
	var who := "Boy" if active_character == "boy" else "Girl"
	var partner := "Girl" if active_character == "boy" else "Boy"
	var msg := ""
	match event_type:
		"harvest":
			msg = "%s: \"Rau vườn mình tươi quá, %s qua phụ bưng nhé!\"" % [who, partner]
		"cook":
			msg = "%s: \"Nồi %s thơm nức mũi luôn!\"" % [who, detail if detail != "" else "Hủ Tiếu"]
		"delivery":
			msg = "%s: \"Chuyến xe %s về an toàn rồi, làm tốt lắm!\"" % [who, detail if detail != "" else "Ga-ra"]
		"upgrade":
			msg = "%s: \"Tiệm mình càng ngày càng khang trang hơn rồi!\"" % who
		"level_up":
			msg = "%s & %s đập tay ăn mừng lên cấp mới!" % [who, partner]
		_:
			msg = "%s mỉm cười nhìn góc nhà ấm áp." % who
	character_reacted.emit(active_character, msg)
	return msg

func do_couple_coop(clock: GameClock, wallet: Wallet, progression: ProgressionSystem = null) -> Dictionary:
	var now_u := clock.now() if clock != null else 0
	if clock != null and last_coop_unix > 0 and (now_u - last_coop_unix) < 45:
		var wait_s := 45 - (now_u - last_coop_unix)
		return {"ok": false, "reason": "Boy & Girl vừa mới phối hợp xong (nghỉ %ds nữa)." % wait_s}
	last_coop_unix = now_u
	cozy_moments_count += 1
	var tasks := [
		"Boy & Girl cùng dọn bếp và chuẩn bị nước dùng thơm phức!",
		"Boy & Girl cùng tưới vườn và kiểm tra xe giao hàng!",
		"Boy & Girl cùng sắp xếp lại kho đồ gọn gàng!"
	]
	last_moment = tasks[(cozy_moments_count - 1) % tasks.size()]
	var bonus_coins := 10
	var bonus_xp := 8
	if wallet != null:
		wallet.earn(bonus_coins)
	var lv_res := {}
	if progression != null:
		lv_res = progression.add_xp(bonus_xp)
	home_changed.emit()
	character_reacted.emit(active_character, last_moment)
	return {
		"ok": true,
		"text": last_moment,
		"coins": bonus_coins,
		"xp": bonus_xp,
		"leveled_up": bool(lv_res.get("leveled_up", false)),
		"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
	}

func to_dict() -> Dictionary:
	var u_rooms: Array[String] = []
	for k in unlocked_rooms.keys():
		u_rooms.append(String(k))
	var o_furn: Array[String] = []
	for k in owned_furniture.keys():
		o_furn.append(String(k))
	return {
		"active_character": active_character,
		"active_room_id": active_room_id,
		"selected_furniture_id": selected_furniture_id,
		"unlocked_rooms": u_rooms,
		"owned_furniture": o_furn,
		"placements": placements.duplicate(true),
		"cozy_moments_count": cozy_moments_count,
		"last_coop_unix": last_coop_unix,
		"last_moment": last_moment
	}

func load_from_dict(d: Dictionary) -> void:
	reset()
	var ch := String(d.get("active_character", "boy"))
	active_character = "girl" if ch == "girl" else "boy"
	var ar := String(d.get("active_room_id", active_room_id))
	if rooms_by_id.has(ar):
		active_room_id = ar

	var raw_ur: Variant = d.get("unlocked_rooms", [])
	if typeof(raw_ur) == TYPE_ARRAY:
		for r in (raw_ur as Array):
			var rid := String(r)
			if rooms_by_id.has(rid):
				unlocked_rooms[rid] = true

	var raw_of: Variant = d.get("owned_furniture", [])
	if typeof(raw_of) == TYPE_ARRAY:
		for f in (raw_of as Array):
			var fid := String(f)
			if items_by_id.has(fid):
				owned_furniture[fid] = true

	var sf := String(d.get("selected_furniture_id", ""))
	if sf != "" and owned_furniture.has(sf):
		selected_furniture_id = sf

	var raw_pl: Variant = d.get("placements", {})
	if typeof(raw_pl) == TYPE_DICTIONARY:
		for rid in (raw_pl as Dictionary).keys():
			if not placements.has(rid):
				continue
			var src_arr: Variant = (raw_pl as Dictionary)[rid]
			if typeof(src_arr) != TYPE_ARRAY:
				continue
			var dst_arr: Array = placements[rid] as Array
			for idx in range(mini(dst_arr.size(), (src_arr as Array).size())):
				var fid := String((src_arr as Array)[idx])
				dst_arr[idx] = fid if (fid == "" or owned_furniture.has(fid)) else ""

	cozy_moments_count = maxi(0, int(d.get("cozy_moments_count", 0)))
	last_coop_unix = maxi(0, int(d.get("last_coop_unix", 0)))
	last_moment = String(d.get("last_moment", ""))
	home_changed.emit()
