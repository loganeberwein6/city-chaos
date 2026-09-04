extends Node
class_name HulkHero

const THROW_RANGE  := 6.0
const THROW_FORCE  := 28.0
const SLAM_RADIUS  := 8.0
const SLAM_DMG     := 150.0
const SLAM_COOLDOWN := 4.0

var _slam_cd := 0.0
var _grab_target: Node3D = null

@onready var _player: CharacterBody3D = get_parent()

func _ready() -> void:
	add_to_group("hero_component")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_1"):
		if _grab_target: _throw()
		else: _try_grab()
	if event.is_action_pressed("ability_2") and _slam_cd <= 0.0:
		_ground_slam()

func _physics_process(delta: float) -> void:
	_slam_cd = maxf(0.0, _slam_cd - delta)
	if _grab_target and is_instance_valid(_grab_target):
		# Carry grabbed NPC in front of player
		_grab_target.global_position = _player.global_position + (-_player.global_transform.basis.z) * 2.0 + Vector3(0, 1.5, 0)

func _try_grab() -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		var nb := npc as NpcBase
		if nb and nb.state != NpcBase.State.DEAD:
			if _player.global_position.distance_to(nb.global_position) < THROW_RANGE:
				_grab_target = nb
				nb.set_physics_process(false)
				return

func _throw() -> void:
	if _grab_target == null: return
	var tgt := _grab_target
	_grab_target = null
	tgt.set_physics_process(true)
	var cam: Camera3D = _player.get_node("SpringArm3D/Camera3D")
	var dir := (-cam.global_transform.basis.z + Vector3(0, 0.4, 0)).normalized()
	tgt.velocity = dir * THROW_FORCE * 3.0
	if tgt.has_method("take_damage"):
		tgt.take_damage(50.0, multiplayer.get_unique_id())

func _ground_slam() -> void:
	_slam_cd = SLAM_COOLDOWN
	# Damage all NPCs and players within radius
	var origin := _player.global_position
	for npc in get_tree().get_nodes_in_group("npcs"):
		var dist := origin.distance_to(npc.global_position)
		if dist < SLAM_RADIUS and npc.has_method("take_damage"):
			var dmg := lerp(SLAM_DMG, 20.0, dist / SLAM_RADIUS)
			npc.take_damage(dmg, multiplayer.get_unique_id())
	# Camera shake via HUD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("camera_shake"):
		hud.camera_shake(0.4)

func get_stat_overrides() -> Dictionary:
	return {"walk_speed": 7.0, "sprint_speed": 14.0, "jump_velocity": 18.0, "max_health": 400.0}
