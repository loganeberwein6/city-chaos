extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

@onready var world_gen:    Node3D = $WorldGenerator
@onready var players_root: Node3D = $PlayersRoot

var _seed_val: int    = 0
var _map_size: String = "medium"

func _ready() -> void:
	_seed_val = GameManager.rules.get("world_seed", randi())
	_map_size = GameManager.rules.get("map_size", "medium")

	world_gen.call("generate", _seed_val, _map_size)
	_bake_navmesh()
	_spawn_local_player()

	if multiplayer.is_server():
		_rpc_sync_world.rpc(_seed_val, _map_size)

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)

@rpc("authority", "reliable", "call_remote")
func _rpc_sync_world(seed_val: int, map_size: String) -> void:
	world_gen.call("generate", seed_val, map_size)
	_bake_navmesh()
	_spawn_local_player()

func _bake_navmesh() -> void:
	var nav: NavigationRegion3D = get_node_or_null("NavigationRegion3D")
	if nav:
		nav.bake_navigation_mesh()

func _spawn_local_player() -> void:
	var my_id: int = multiplayer.get_unique_id()
	if players_root.get_node_or_null(str(my_id)) != null:
		return
	var my_data: Dictionary = NetworkManager.connected_players.get(my_id, {})
	var hero: String = my_data.get("hero", "normal_person")
	var player: Node3D = PLAYER_SCENE.instantiate() as Node3D
	player.name     = str(my_id)
	player.position = GameManager.get_spawn_point()
	player.set("hero_id", hero)
	players_root.add_child(player, true)
	if multiplayer.is_server():
		_rpc_spawn_remote_player.rpc(my_id, player.position, hero)

@rpc("authority", "reliable", "call_remote")
func _rpc_spawn_remote_player(peer_id: int, pos: Vector3, hero: String = "normal_person") -> void:
	if players_root.get_node_or_null(str(peer_id)) != null:
		return
	var player: Node3D = PLAYER_SCENE.instantiate() as Node3D
	player.name     = str(peer_id)
	player.position = pos
	player.set("hero_id", hero)
	players_root.add_child(player, true)

func _on_player_joined(peer_id: int, data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_rpc_sync_world.rpc_id(peer_id, _seed_val, _map_size)
	var hero: String = data.get("hero", "normal_person")
	if players_root.get_node_or_null(str(peer_id)) == null:
		var player: Node3D = PLAYER_SCENE.instantiate() as Node3D
		player.name     = str(peer_id)
		player.position = GameManager.get_spawn_point()
		player.set("hero_id", hero)
		players_root.add_child(player, true)
		_rpc_spawn_remote_player.rpc(peer_id, player.position, hero)
	for existing in players_root.get_children():
		var eid: int = existing.name.to_int() if existing.name.is_valid_int() else -1
		if eid > 0 and eid != peer_id:
			var edata: Dictionary = NetworkManager.connected_players.get(eid, {})
			var ehero: String = edata.get("hero", "normal_person")
			_rpc_spawn_remote_player.rpc_id(peer_id, eid, existing.position, ehero)

func _on_player_left(peer_id: int) -> void:
	var node: Node = players_root.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
