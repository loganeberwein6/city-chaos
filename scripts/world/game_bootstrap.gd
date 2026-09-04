extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var world_gen:    WorldGenerator = $WorldGenerator
@onready var players_root: Node3D         = $PlayersRoot
@onready var _loading:     CanvasLayer    = $LoadingOverlay

func _ready() -> void:
	var seed_val: int    = GameManager.rules.get("world_seed", randi())
	var map_size: String = GameManager.rules.get("map_size", "medium")

	# generate() is fully synchronous — spawn points are registered by the time it returns
	world_gen.generate(seed_val, map_size)
	_spawn_local_player()
	_loading.visible = false

	if multiplayer.is_server():
		_rpc_sync_world.rpc(seed_val, map_size)

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)

@rpc("authority", "reliable", "call_remote")
func _rpc_sync_world(seed_val: int, map_size: String) -> void:
	world_gen.generate(seed_val, map_size)
	_spawn_local_player()
	_loading.visible = false

func _spawn_local_player() -> void:
	var my_id: int = multiplayer.get_unique_id()
	if players_root.get_node_or_null(str(my_id)) != null:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name     = str(my_id)
	player.position = GameManager.get_spawn_point()
	players_root.add_child(player, true)
	if multiplayer.is_server():
		_rpc_spawn_remote_player.rpc(my_id, player.position)

@rpc("authority", "reliable", "call_remote")
func _rpc_spawn_remote_player(peer_id: int, pos: Vector3) -> void:
	if players_root.get_node_or_null(str(peer_id)) != null:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name     = str(peer_id)
	player.position = pos
	players_root.add_child(player, true)

func _on_player_joined(peer_id: int, _data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if players_root.get_node_or_null(str(peer_id)) == null:
		var player := PLAYER_SCENE.instantiate()
		player.name     = str(peer_id)
		player.position = GameManager.get_spawn_point()
		players_root.add_child(player, true)
		_rpc_spawn_remote_player.rpc(peer_id, player.position)
	for existing in players_root.get_children():
		var eid: int = existing.name.to_int() if existing.name.is_valid_int() else -1
		if eid > 0 and eid != peer_id:
			_rpc_spawn_remote_player.rpc_id(peer_id, eid, existing.position)

func _on_player_left(peer_id: int) -> void:
	var node := players_root.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
