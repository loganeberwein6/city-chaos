extends Node

# Put .wav files in res://audio/sfx/ named e.g. "gunshot_pistol.wav", "punch.wav".
# Missing sounds warn once and are silently skipped after that.

const POOL_SIZE := 10
const SFX_DIR   := "res://audio/sfx/"

var _pool: Array[AudioStreamPlayer3D] = []
var _pool_idx := 0
var _warned: Dictionary = {}

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.max_distance = 80.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		add_child(player)
		_pool.append(player)

func play_3d(sfx_name: String, world_pos: Vector3) -> void:
	var path := SFX_DIR + sfx_name + ".wav"
	if not ResourceLoader.exists(path):
		if not _warned.has(sfx_name):
			_warned[sfx_name] = true
			push_warning("AudioManager: missing audio file '%s'" % path)
		return
	var player := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	player.stream = load(path)
	player.global_position = world_pos
	player.play()
