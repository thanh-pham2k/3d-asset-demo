class_name NeighborhoodSystem
extends RefCounted
## Manages unlockable neighborhood areas, area builds, NPC profiles/requests, recurring chats, and one-time story milestones.

signal neighborhood_changed()

var areas_by_id: Dictionary = {}
var area_ids_sorted: Array[String] = []
var npcs_by_id: Dictionary = {}
var npc_ids_sorted: Array[String] = []

# Persistent state
var active_area_id: String = "alley_corner"
var unlocked_areas: Dictionary = {} # area_id -> true
var built_areas: Dictionary = {} # area_id -> true
var npc_helps: Dictionary = {} # npc_id -> int
var npc_chats: Dictionary = {} # npc_id -> int
var claimed_stories: Dictionary = {} # milestone_id -> true
var last_story_text: String = ""

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)
	reset()

func apply_config(cfg: Dictionary) -> void:
	areas_by_id.clear()
	area_ids_sorted.clear()
	var raw_areas: Variant = cfg.get("areas", [])
	if typeof(raw_areas) == TYPE_ARRAY:
		for entry in (raw_areas as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var a := (entry as Dictionary).duplicate(true)
			var aid := String(a.get("id", ""))
			if aid != "":
				areas_by_id[aid] = a
				area_ids_sorted.append(aid)

	npcs_by_id.clear()
	npc_ids_sorted.clear()
	var raw_npcs: Variant = cfg.get("npcs", [])
	if typeof(raw_npcs) == TYPE_ARRAY:
		for entry in (raw_npcs as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var n := (entry as Dictionary).duplicate(true)
			var nid := String(n.get("id", ""))
			if nid != "":
				npcs_by_id[nid] = n
				npc_ids_sorted.append(nid)

func reset() -> void:
	active_area_id = area_ids_sorted[0] if not area_ids_sorted.is_empty() else "alley_corner"
	unlocked_areas.clear()
	built_areas.clear()
	npc_helps.clear()
	npc_chats.clear()
	claimed_stories.clear()
	last_story_text = "Khu phố đang yên bình chờ Boy & Girl ghé thăm."
	for aid: String in area_ids_sorted:
		var a := areas_by_id[aid] as Dictionary
		if bool(a.get("unlocked_by_default", false)):
			unlocked_areas[aid] = true
	neighborhood_changed.emit()

func select_area(aid: String) -> bool:
	if not areas_by_id.has(aid):
		return false
	active_area_id = aid
	neighborhood_changed.emit()
	return true

func is_area_unlocked(aid: String) -> bool:
	return unlocked_areas.has(aid)

func is_area_built(aid: String) -> bool:
	return built_areas.has(aid)

func unlock_area(aid: String, player_level: int, wallet: Wallet) -> Dictionary:
	if not areas_by_id.has(aid):
		return {"ok": false, "reason": "Khu vực không tồn tại."}
	if unlocked_areas.has(aid):
		return {"ok": false, "reason": "Khu vực này đã mở khóa."}
	var a := areas_by_id[aid] as Dictionary
	var min_lv := int(a.get("min_level", 1))
	if player_level < min_lv:
		return {"ok": false, "reason": "Cần đạt Lv.%d để mở khu vực này." % min_lv}
	var cost := maxi(0, int(a.get("unlock_cost", 0)))
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}
	unlocked_areas[aid] = true
	neighborhood_changed.emit()
	return {"ok": true, "cost": cost, "area_id": aid}

func build_area_project(aid: String, wallet: Wallet, inventory: Inventory) -> Dictionary:
	if not areas_by_id.has(aid) or not unlocked_areas.has(aid):
		return {"ok": false, "reason": "Hãy mở khóa khu vực trước."}
	if built_areas.has(aid):
		return {"ok": false, "reason": "Công trình khu phố này đã hoàn thành."}
	var a := areas_by_id[aid] as Dictionary
	var cost := maxi(0, int(a.get("build_cost", 0)))
	var req_items := a.get("build_items", {}) as Dictionary
	if not wallet.can_afford(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}
	for iid: String in req_items.keys():
		if inventory.get_count(iid) < int(req_items[iid]):
			return {"ok": false, "reason": "Thiếu vật tư (%s x%d)." % [iid, int(req_items[iid])]}

	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu."}
	for iid: String in req_items.keys():
		if not inventory.remove_item(iid, int(req_items[iid])):
			wallet.earn(cost)
			return {"ok": false, "reason": "Lỗi xuất kho vật tư."}

	built_areas[aid] = true
	last_story_text = "🔨 Đã hoàn thành công trình '%s' cho %s!" % [String(a.get("build_name", "")), String(a.get("display_name", aid))]
	neighborhood_changed.emit()
	return {"ok": true, "cost": cost, "build_name": String(a.get("build_name", ""))}

func chat_with_npc(nid: String) -> Dictionary:
	if not npcs_by_id.has(nid):
		return {"ok": false, "reason": "NPC không tồn tại."}
	var n := npcs_by_id[nid] as Dictionary
	var aid := String(n.get("area_id", ""))
	if aid != "" and not unlocked_areas.has(aid):
		return {"ok": false, "reason": "Hãy mở khóa khu vực của nhân vật này trước."}
	var cnt := int(npc_chats.get(nid, 0)) + 1
	npc_chats[nid] = cnt
	var lines := n.get("chat_lines", []) as Array
	var line := "Xin chào Boy & Girl!"
	if not lines.is_empty():
		line = String(lines[(cnt - 1) % lines.size()])
	last_story_text = line
	neighborhood_changed.emit()
	return {"ok": true, "text": line, "chats": cnt}

func fulfill_npc_request(nid: String, inventory: Inventory, wallet: Wallet, progression: ProgressionSystem) -> Dictionary:
	if not npcs_by_id.has(nid):
		return {"ok": false, "reason": "NPC không tồn tại."}
	var n := npcs_by_id[nid] as Dictionary
	var aid := String(n.get("area_id", ""))
	if aid != "" and not unlocked_areas.has(aid):
		return {"ok": false, "reason": "Hãy mở khóa khu vực trước."}

	var reqs := n.get("request", {}) as Dictionary
	for iid: String in reqs.keys():
		if inventory.get_count(iid) < int(reqs[iid]):
			return {"ok": false, "reason": "Thiếu vật phẩm (%s x%d)." % [iid, int(reqs[iid])]}

	# Atomic deduction
	var consumed: Array[Dictionary] = []
	for iid: String in reqs.keys():
		var amt := int(reqs[iid])
		if not inventory.remove_item(iid, amt):
			for prev in consumed:
				inventory.add_item(String(prev["id"]), int(prev["amt"]))
			return {"ok": false, "reason": "Lỗi trừ vật phẩm kho."}
		consumed.append({"id": iid, "amt": amt})

	var helps := int(npc_helps.get(nid, 0)) + 1
	npc_helps[nid] = helps
	var coins := maxi(0, int(n.get("reward_coins", 0)))
	var xp := maxi(0, int(n.get("reward_xp", 0)))
	if coins > 0 and wallet != null:
		wallet.earn(coins)
	var lv_res := {}
	if xp > 0 and progression != null:
		lv_res = progression.add_xp(xp)

	last_story_text = "🤝 Đã giúp %s hoàn thành yêu cầu (Lần #%d)!" % [String(n.get("display_name", nid)), helps]
	neighborhood_changed.emit()
	return {
		"ok": true,
		"helps": helps,
		"coins": coins,
		"xp": xp,
		"leveled_up": bool(lv_res.get("leveled_up", false)),
		"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
	}

func can_claim_story(nid: String) -> bool:
	if not npcs_by_id.has(nid):
		return false
	var n := npcs_by_id[nid] as Dictionary
	var st := n.get("story_milestone", {}) as Dictionary
	if st.is_empty():
		return false
	var mid := String(st.get("id", ""))
	if mid == "" or claimed_stories.has(mid):
		return false
	var req := int(st.get("required_helps", 1))
	return int(npc_helps.get(nid, 0)) >= req

func is_story_claimed(nid: String) -> bool:
	if not npcs_by_id.has(nid):
		return false
	var n := npcs_by_id[nid] as Dictionary
	var st := n.get("story_milestone", {}) as Dictionary
	return claimed_stories.has(String(st.get("id", "")))

func claim_story_milestone(nid: String, wallet: Wallet, progression: ProgressionSystem, home: HomeSystem = null, pets: PetSystem = null) -> Dictionary:
	if not npcs_by_id.has(nid):
		return {"ok": false, "reason": "NPC không tồn tại."}
	var n := npcs_by_id[nid] as Dictionary
	var st := n.get("story_milestone", {}) as Dictionary
	var mid := String(st.get("id", ""))
	if mid == "":
		return {"ok": false, "reason": "Không có câu chuyện."}
	if claimed_stories.has(mid):
		return {"ok": false, "reason": "Cột mốc câu chuyện này đã được nhận rồi."}
	var req := int(st.get("required_helps", 1))
	if int(npc_helps.get(nid, 0)) < req:
		return {"ok": false, "reason": "Hãy giúp %s ít nhất %d lần để mở khóa câu chuyện." % [String(n.get("display_name", nid)), req]}

	claimed_stories[mid] = true
	var coins := maxi(0, int(st.get("reward_coins", 0)))
	var xp := maxi(0, int(st.get("reward_xp", 0)))
	if coins > 0 and wallet != null:
		wallet.earn(coins)
	var lv_res := {}
	if xp > 0 and progression != null:
		lv_res = progression.add_xp(xp)

	var spec_granted := ""
	var spec := st.get("special_reward", {}) as Dictionary
	if not spec.is_empty():
		var s_type := String(spec.get("type", ""))
		var s_id := String(spec.get("id", ""))
		var s_name := String(spec.get("display_name", s_id))
		if s_type == "home_furniture" and home != null and home.items_by_id.has(s_id):
			if not home.owned_furniture.has(s_id):
				home.owned_furniture[s_id] = true
				spec_granted = s_name
			elif wallet != null:
				wallet.earn(25)
				spec_granted = s_name + " (đã có → +25 xu)"
		elif s_type == "pet_item" and pets != null and pets.items_by_id.has(s_id):
			if not pets.owned_items.has(s_id):
				pets.owned_items[s_id] = true
				pets._sync_unlocked_behaviors()
				spec_granted = s_name
			elif wallet != null:
				wallet.earn(25)
				spec_granted = s_name + " (đã có → +25 xu)"

	last_story_text = "📖 [%s] %s" % [String(st.get("title", "")), String(st.get("text", ""))]
	neighborhood_changed.emit()
	return {
		"ok": true,
		"title": String(st.get("title", "")),
		"coins": coins,
		"xp": xp,
		"special": spec_granted,
		"leveled_up": bool(lv_res.get("leveled_up", false)),
		"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
	}

func to_dict() -> Dictionary:
	var unl_arr: Array[String] = []
	for aid: String in unlocked_areas.keys():
		unl_arr.append(aid)
	var bld_arr: Array[String] = []
	for aid: String in built_areas.keys():
		bld_arr.append(aid)
	var st_arr: Array[String] = []
	for mid: String in claimed_stories.keys():
		st_arr.append(mid)
	return {
		"active_area_id": active_area_id,
		"unlocked_areas": unl_arr,
		"built_areas": bld_arr,
		"npc_helps": npc_helps.duplicate(true),
		"npc_chats": npc_chats.duplicate(true),
		"claimed_stories": st_arr,
		"last_story_text": last_story_text
	}

func load_from_dict(data: Dictionary) -> void:
	reset()
	var aa := String(data.get("active_area_id", ""))
	if aa != "" and areas_by_id.has(aa):
		active_area_id = aa

	var raw_unl: Variant = data.get("unlocked_areas", [])
	if typeof(raw_unl) == TYPE_ARRAY:
		for v in (raw_unl as Array):
			var aid := String(v)
			if areas_by_id.has(aid):
				unlocked_areas[aid] = true

	var raw_bld: Variant = data.get("built_areas", [])
	if typeof(raw_bld) == TYPE_ARRAY:
		for v in (raw_bld as Array):
			var aid := String(v)
			if areas_by_id.has(aid):
				built_areas[aid] = true

	var raw_helps: Variant = data.get("npc_helps", {})
	if typeof(raw_helps) == TYPE_DICTIONARY:
		for nid: String in (raw_helps as Dictionary).keys():
			if npcs_by_id.has(nid):
				npc_helps[nid] = maxi(0, int((raw_helps as Dictionary)[nid]))

	var raw_chats: Variant = data.get("npc_chats", {})
	if typeof(raw_chats) == TYPE_DICTIONARY:
		for nid: String in (raw_chats as Dictionary).keys():
			if npcs_by_id.has(nid):
				npc_chats[nid] = maxi(0, int((raw_chats as Dictionary)[nid]))

	var raw_st: Variant = data.get("claimed_stories", [])
	if typeof(raw_st) == TYPE_ARRAY:
		for v in (raw_st as Array):
			claimed_stories[String(v)] = true

	var ls := String(data.get("last_story_text", ""))
	if ls != "":
		last_story_text = ls
	neighborhood_changed.emit()
