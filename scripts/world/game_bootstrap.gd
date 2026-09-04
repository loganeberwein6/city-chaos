extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var world_gen    := $WorldGenerator
@onready var players_root := $PlayersRoot

func _ready() -> void:
	var seed_val: int    = GameManager.rules.get("world_seed", randi())
	var map_size: String = GameManager.rules.get("map_size", "medium")

	world_gen.world_ready.connect(_on_world_ready)
	world_gen.generate(seed_val, map_size)

	if multiplayer.is_server():
		_rpc_sync_world.rpc(seed_val, map_size)

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)

# Called on the SERVER when world finishes generating
func _on_world_ready() -> void:
	_spawn_local_player()

# Called on CLIENTS when they receive the seed from the server
@rpc("authority", "reliable", "call_remote")
func _rpc_sync_world(seed_val: int, map_size: String) -> void:
	world_gen.generate(seed_val, map_size)
	# world_ready fires inside generate(), so _on_world_ready connects below won't
	# fire on clients — spawn client player here instead
	_spawn_local_player()

func _spawn_local_player() -> void:
	var my_id := multiplayer.get_unique_id()
	# Guard: only spawn once
	if players_root.get_node_or_null(str(my_id)) != null:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name  = str(my_id)
	player.position = GameManager.get_spawn_point()
	players_root.add_child(player, true)
	# Tell others to also spawn this player (server only; clients tell server who they are)
	if multiplayer.is_server():
		_rpc_spawn_remote_player.rpc(my_id, player.position)

# Tell all remote peers to add a player node for peer_id at pos
@rpc("authority", "reliable", "call_remote")
func _rpc_spawn_remote_player(peer_id: int, pos: Vector3) -> void:
	if players_root.get_node_or_null(str(peer_id)) != null:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name     = str(peer_id)
	player.position = pos
	players_root.add_child(player, true)

# Server spawns a new joining client's player and notifies everyone
func _on_player_joined(peer_id: int, _data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# Spawn on the server
	if players_root.get_node_or_null(str(peer_id)) == null:
		var player := PLAYER_SCENE.instantiate()
		player.name     = str(peer_id)
		player.position = GameManager.get_spawn_point()
		players_root.add_child(player, true)
		# Tell everyone including the new client to spawn this player
		_rpc_spawn_remote_player.rpc(peer_id, player.position)
	# Also tell the new client about all currently spawned players
	for existing in players_root.get_children():
		var eid := existing.name.to_int() if existing.name.is_valid_int() else -1
		if eid > 0 and eid != peer_id:
			_rpc_spawn_remote_player.rpc_id(peer_id, eid, existing.position)

func _on_player_left(peer_id: int) -> void:
	var node := players_root.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
