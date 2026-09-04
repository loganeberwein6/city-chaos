extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var world_gen:     Node3D = $WorldGenerator
@onready var players_root:  Node3D = $PlayersRoot
@onready var spawner: MultiplayerSpawner = $PlayersRoot/MultiplayerSpawner
@onready var npc_spawner: NpcSpawner     = $NpcSpawner
@onready var vehicle_spawner: VehicleSpawner = $VehicleSpawner
@onready var police_response: PoliceResponse = $PoliceResponse

func _ready() -> void:
	spawner.spawn_function = _spawn_player

	if multiplayer.is_server():
		var seed_val: int = GameManager.rules.get("world_seed", randi())
		var map_size: String = GameManager.rules.get("map_size", "medium")
		world_gen.world_ready.connect(_on_world_ready)
		world_gen.generate(seed_val, map_size)
		_rpc_sync_world.rpc(seed_val, map_size)
	else:
		pass

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)

@rpc("authority", "reliable", "call_remote")
func _rpc_sync_world(seed_val: int, map_size: String) -> void:
	world_gen.generate(seed_val, map_size)

func _on_world_ready() -> void:
	# Spawn own player
	var my_id := multiplayer.get_unique_id()
	spawner.spawn(my_id)

func _spawn_player(peer_id: int) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	var spawn_pos := GameManager.get_spawn_point()
	player.position = spawn_pos
	return player

func _on_player_joined(peer_id: int, _data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	spawner.spawn(peer_id)

func _on_player_left(peer_id: int) -> void:
	var node := players_root.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()
