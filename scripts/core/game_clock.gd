class_name GameClock
extends RefCounted
## Deterministic game clock supporting real-time Unix timestamps and debug fast-forward.

var clock_offset_sec: int = 0

func now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_offset_sec

func advance(seconds: int) -> void:
	if seconds <= 0:
		return
	clock_offset_sec += seconds

func reset() -> void:
	clock_offset_sec = 0

func get_offset() -> int:
	return clock_offset_sec

func set_offset(offset_sec: int) -> void:
	clock_offset_sec = offset_sec

func offline_elapsed(last_saved_real_unix: int) -> int:
	if last_saved_real_unix <= 0:
		return 0
	return maxi(0, int(Time.get_unix_time_from_system()) - last_saved_real_unix)

static func format_duration(seconds: int) -> String:
	var clamped := maxi(0, seconds)
	var hours := int(clamped / 3600)
	var mins := int((clamped % 3600) / 60)
	var secs := int(clamped % 60)
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, mins, secs]
	return "%02d:%02d" % [mins, secs]
