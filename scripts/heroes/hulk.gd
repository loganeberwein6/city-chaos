extends Node

# Hulk hero component — attached as child of player_controller.
# Abilities: Ground Slam (Q while in air), Grab/Throw (E near NPC).

const SLAM_DIVE_SPEED  := 40.0
const SLAM_RADIUS      := 5.0
const SLAM_DAMAGE      := 50.0
const GRAB_RANGE       := 3.0
const THROW_SPEED      := 20.0

var _slam_pending  := false   # true after Q pressed in air, waiting for landing
var _held_npc: Node3D = null

func get_stat_overrides() -> Dictionary:
	return {
		"walk_speed":    5.0,
		"sprint_speed":  8.0,
		"jump_velocity": 14.0,
		"max_health":    400.0,
	}

func _physics_process(_delta: float) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return

	var cb: CharacterBody3D = player as CharacterBody3D
	if cb == null:
		return

	# Carry held NPC in front of player
	if _held_npc != null and is_instance_valid(_held_npc):
		_held_npc.global_position = cb.global_position + (-cb.global_transform.basis.z) * 2.0 + Vector3(0.0, 1.2, 0.0)

	# Detect landing after ground slam
	if _slam_pending and cb.is_on_floor():
		_slam_pending = false
		_do_slam_shockwave(cb)

func _unhandled_input(event: InputEvent) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return

	var cb: CharacterBody3D = player as CharacterBody3D
	if cb == null:
		return

	# Ground Slam — Q while in air
	if event.is_action_pressed("ability_1"):
		if not cb.is_on_floor() and not _slam_pending:
			_slam_pending = true
			cb.velocity.y = -SLAM_DIVE_SPEED

	# Grab / Throw — E
	if event.is_action_pressed("ability_2"):
		if _held_npc != null and is_instance_valid(_held_npc):
			_throw_npc(player, cb)
		else:
			_try_grab(cb)

func _try_grab(cb: CharacterBody3D) -> void:
	var cam_node: Node = cb.get_node("SpringArm3D/Camera3D")
	var cam: Camera3D = cam_node as Camera3D
	if cam == null:
		return
	var from := cam.global_position
	var to   := from + (-cam.global_transform.basis.z) * GRAB_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [cb.get_rid()]
	var result := cb.get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return
	var hit: Object = result["collider"]
	if hit is Node3D and hit != cb:
		_held_npc = hit as Node3D
		if _held_npc.has_method("set_physics_process"):
			_held_npc.set_physics_process(false)

func _throw_npc(player: Node, cb: CharacterBody3D) -> void:
	var tgt: Node3D = _held_npc
	_held_npc = null
	if tgt == null or not is_instance_valid(tgt):
		return
	if tgt.has_method("set_physics_process"):
		tgt.set_physics_process(true)
	var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")
	var forward := (-cam.global_transform.basis.z + Vector3(0.0, 0.3, 0.0)).normalized()
	if tgt is CharacterBody3D:
		(tgt as CharacterBody3D).velocity = forward * THROW_SPEED
	if tgt.has_method("take_damage"):
		tgt.call("take_damage", 30.0, multiplayer.get_unique_id())

func _do_slam_shockwave(cb: CharacterBody3D) -> void:
	var origin := cb.global_position
	# Damage players within radius
	for p in cb.get_tree().get_nodes_in_group("players"):
		if p == cb:
			continue
		if not is_instance_valid(p):
			continue
		if origin.distance_to((p as Node3D).global_position) <= SLAM_RADIUS:
			if p.has_method("take_damage"):
				p.call("take_damage", SLAM_DAMAGE, multiplayer.get_unique_id())
