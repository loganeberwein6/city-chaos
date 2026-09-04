extends Node

const HISTORY_SIZE := 90

var _history: Array[Dictionary] = []

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var snap: Dictionary = {}
	for pid in GameManager._players:
		var p: Node3D = GameManager._players[pid]
		if p and is_instance_valid(p):
			snap[pid] = p.global_position
	_history.push_back({"time": Time.get_ticks_msec(), "snap": snap})
	if _history.size() > HISTORY_SIZE:
		_history.pop_front()

func get_snapshot_at(target_ms: int) -> Dictionary:
	if _history.is_empty():
		return {}
	var best: Dictionary = _history[0]
	var best_diff := INF
	for entry in _history:
		var diff: float = absf(float(entry["time"] - target_ms))
		if diff < best_diff:
			best_diff = diff
			best = entry
	return best.get("snap", {})
