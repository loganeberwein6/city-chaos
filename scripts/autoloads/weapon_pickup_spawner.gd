extends Node

# Spawns weapon pickups at fixed world positions. Pickups respawn RESPAWN_DELAY
# seconds after being collected. Only active on the server.

const RESPAWN_DELAY := 30.0
const PICKUP_SCENE  := "res://scenes/weapons/weapon_pickup.tscn"

# Each entry: [Vector3 position, weapon_id, ammo, reserve]
const SPAWN_TABLE: Array = [
	[Vector3(10.0,  1.0,  10.0), "pistol",        12,  24],
	[Vector3(-10.0, 1.0,  10.0), "assault_rifle", 30,  60],
	[Vector3(0.0,   1.0,  28.0), "shotgun",         8,  16],
	[Vector3(28.0,  1.0,   0.0), "sniper",          5,  10],
	[Vector3(-28.0, 1.0,   0.0), "smg",            30,  90],
	[Vector3(10.0,  1.0, -28.0), "pistol",         12,  24],
	[Vector3(-10.0, 1.0, -28.0), "assault_rifle",  30,  60],
	[Vector3(38.0,  1.0,  38.0), "shotgun",         8,  16],
	[Vector3(-38.0, 1.0,  38.0), "revolver",        6,  18],
	[Vector3(38.0,  1.0, -38.0), "rpg",             1,   2],
]

var _scene: PackedScene = null
var _respawn_queue: Array = []
var _initialized := false

func _ready() -> void:
	if ResourceLoader.exists(PICKUP_SCENE):
		_scene = load(PICKUP_SCENE)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if _initialized or not multiplayer.is_server():
		return
	if node.scene_file_path.ends_with("game.tscn"):
		_initialized = true
		call_deferred("_spawn_all")

func _spawn_all() -> void:
	for entry in SPAWN_TABLE:
		_spawn_pickup(entry[0], entry[1], entry[2], entry[3])

func _spawn_pickup(pos: Vector3, wid: String, ammo: int, reserve: int) -> void:
	if _scene == null:
		return
	var pickup: Node3D = _scene.instantiate()
	pickup.set("weapon_id", wid)
	pickup.set("ammo_count", ammo)
	pickup.set("reserve", reserve)
	get_tree().root.add_child(pickup)
	pickup.global_position = pos
	pickup.tree_exited.connect(func():
		_respawn_queue.append({"pos": pos, "wid": wid, "ammo": ammo, "reserve": reserve, "timer": RESPAWN_DELAY})
	)

func _process(delta: float) -> void:
	if not multiplayer.is_server() or not _initialized:
		return
	var remaining: Array = []
	for entry in _respawn_queue:
		entry["timer"] -= delta
		if entry["timer"] <= 0.0:
			_spawn_pickup(entry["pos"], entry["wid"], entry["ammo"], entry["reserve"])
		else:
			remaining.append(entry)
	_respawn_queue = remaining
