extends Control
class_name Minimap

const _NpcBase = preload("res://scripts/npc/npc_base.gd")

const RADIUS := 70.0
const SCALE  := 0.6
const BG_COLOR    := Color(0.05, 0.1, 0.1, 0.8)
const GRID_COLOR  := Color(0.15, 0.25, 0.2, 0.5)
const PLAYER_COLOR := Color(0.2, 1.0, 0.3)
const NPC_CIV_COLOR := Color(0.7, 0.7, 0.7, 0.7)
const NPC_COP_COLOR := Color(0.2, 0.4, 1.0)
const NPC_GANG_COLOR := Color(0.9, 0.2, 0.2)
const VEHICLE_COLOR := Color(1.0, 0.8, 0.1, 0.8)

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, RADIUS, BG_COLOR)
	draw_arc(center, RADIUS, 0, TAU, 40, Color(0.4, 0.6, 0.5, 0.8), 1.5)

	var local_id := multiplayer.get_unique_id()
	var local_player: Node3D = GameManager.get_player_node(local_id)
	if local_player == null: return

	var origin := local_player.global_position

	for pid in GameManager._players:
		var p: Node3D = GameManager._players[pid]
		if p == null or not is_instance_valid(p): continue
		var offset := _world_to_map(p.global_position - origin)
		if offset.length() > RADIUS: continue
		var dot_color := PLAYER_COLOR if pid == local_id else Color(0.1, 0.8, 1.0)
		draw_circle(center + offset, 4.0 if pid == local_id else 3.0, dot_color)

	for npc in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(npc): continue
		if npc.get("state") == _NpcBase.State.DEAD: continue
		var offset := _world_to_map(npc.global_position - origin)
		if offset.length() > RADIUS: continue
		draw_circle(center + offset, 2.5, _npc_color(npc))

	for v in get_tree().get_nodes_in_group("vehicles"):
		if not is_instance_valid(v): continue
		var offset := _world_to_map(v.global_position - origin)
		if offset.length() > RADIUS: continue
		draw_rect(Rect2(center + offset - Vector2(3,3), Vector2(6, 6)), VEHICLE_COLOR)

func _world_to_map(world_offset: Vector3) -> Vector2:
	return Vector2(world_offset.x, -world_offset.z) / SCALE

func _npc_color(npc: Node3D) -> Color:
	var faction = npc.get("faction")
	if faction == _NpcBase.Faction.POLICE:   return NPC_COP_COLOR
	if faction == _NpcBase.Faction.GANGSTER: return NPC_GANG_COLOR
	return NPC_CIV_COLOR
