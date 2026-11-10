class_name CoopMissionManager
extends Node

## Coordinates 2-player cooperative missions and shared milestone achievements.
## Awards synergy bonuses to the shared household wallet upon completion.

signal mission_started(mission_id: String, title: String)
signal mission_progress(mission_id: String, current: int, target: int)
signal mission_completed(mission_id: String, title: String, reward: int)

var active_missions: Dictionary = {
	"coop_rush_hour": {
		"title": "Giờ Cao Điểm Đồng Lòng",
		"desc": "Cả hai cùng phối hợp hoàn tất 4 đơn sửa xe và bán hủ tiếu",
		"target": 4,
		"current": 0,
		"reward": 60000,
		"completed": false
	},
	"coop_team_carry": {
		"title": "Chung Tay Khiêng Vác",
		"desc": "Cùng nâng và di chuyển 1 món đồ nội thất nặng",
		"target": 1,
		"current": 0,
		"reward": 40000,
		"completed": false
	},
	"coop_assemble_master": {
		"title": "Thợ Lắp Ráp Điêu Luyện",
		"desc": "Cùng lắp ráp hoàn chỉnh 1 món nội thất flatpack",
		"target": 1,
		"current": 0,
		"reward": 50000,
		"completed": false
	}
}

func report_progress(mission_id: String, amount: int = 1, wallet: HouseholdWallet = null) -> bool:
	if not active_missions.has(mission_id): return false
	var m: Dictionary = active_missions[mission_id]
	if m["completed"]: return false
	
	m["current"] += amount
	mission_progress.emit(mission_id, m["current"], m["target"])
	
	if m["current"] >= m["target"]:
		m["completed"] = true
		var rew: int = m["reward"]
		if wallet:
			wallet.deposit(rew, "coop_mission", "Thưởng nhiệm vụ co-op: " + m["title"])
		mission_completed.emit(mission_id, m["title"], rew)
		return true
	return false

func is_mission_completed(mission_id: String) -> bool:
	return active_missions.has(mission_id) and active_missions[mission_id].get("completed", false)

func complete_mission(mission_id: String, wallet: HouseholdWallet = null) -> bool:
	if not active_missions.has(mission_id): return false
	var needed: int = active_missions[mission_id]["target"] - active_missions[mission_id]["current"]
	return report_progress(mission_id, maxi(1, needed), wallet)
