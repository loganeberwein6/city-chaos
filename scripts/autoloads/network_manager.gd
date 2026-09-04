extends Node

signal server_found(info: Dictionary)
signal server_list_cleared()
signal player_joined(peer_id: int, data: Dictionary)
signal player_left(peer_id: int)
signal connected_to_host()
signal connection_failed()
signal host_disconnected()

const GAME_PORT    := 7777
const BEACON_PORT  := 7778
const BEACON_INTERVAL := 2.0

var is_hosting := false
var session_name := "Game"
var connected_players: Dictionary = {}  # peer_id -> player data
var discovered_servers: Dictionary = {}  # ip -> info

var _beacon_socket: PacketPeerUDP
var _listen_socket: PacketPeerUDP
var _beacon_timer: float = 0.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ── Hosting ──────────────────────────────────────────────────────────────────

func host(name: String) -> bool:
	session_name = name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT)
	if err != OK:
		push_error("Host failed: %s" % error_string(err))
		return false
	multiplayer.multiplayer_peer = peer
	is_hosting = true
	connected_players[1] = {"name": name, "peer_id": 1}
	_start_beacon()
	return true

func _start_beacon() -> void:
	_beacon_socket = PacketPeerUDP.new()
	_beacon_socket.bind(0)
	_beacon_socket.set_broadcast_enabled(true)

func _stop_beacon() -> void:
	if _beacon_socket:
		_beacon_socket.close()
		_beacon_socket = null

func _broadcast_beacon() -> void:
	if not _beacon_socket:
		return
	var info := JSON.stringify({
		"name": session_name,
		"players": connected_players.size(),
		"port": GAME_PORT,
	})
	_beacon_socket.set_dest_address("255.255.255.255", BEACON_PORT)
	_beacon_socket.put_packet(info.to_utf8_buffer())

# ── Discovery ─────────────────────────────────────────────────────────────────

func start_discovery() -> void:
	discovered_servers.clear()
	server_list_cleared.emit()
	_listen_socket = PacketPeerUDP.new()
	_listen_socket.bind(BEACON_PORT)

func stop_discovery() -> void:
	if _listen_socket:
		_listen_socket.close()
		_listen_socket = null

func _poll_discovery() -> void:
	if not _listen_socket:
		return
	while _listen_socket.get_available_packet_count() > 0:
		var pkt := _listen_socket.get_packet()
		var ip  := _listen_socket.get_packet_ip()
		var text := pkt.get_string_from_utf8()
		var info = JSON.parse_string(text)
		if info is Dictionary:
			info["ip"] = ip
			discovered_servers[ip] = info
			server_found.emit(info)

# ── Joining ───────────────────────────────────────────────────────────────────

func join(ip: String, port: int = GAME_PORT) -> void:
	stop_discovery()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Join failed: %s" % error_string(err))
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer

func disconnect_from_session() -> void:
	_stop_beacon()
	stop_discovery()
	multiplayer.multiplayer_peer = null
	is_hosting = false
	connected_players.clear()
	discovered_servers.clear()

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if is_hosting:
		_beacon_timer += delta
		if _beacon_timer >= BEACON_INTERVAL:
			_beacon_timer = 0.0
			_broadcast_beacon()
	_poll_discovery()

# ── RPC: player registration ──────────────────────────────────────────────────

func register_self(player_name: String, chosen_hero: String) -> void:
	var data := {"name": player_name, "hero": chosen_hero, "peer_id": multiplayer.get_unique_id()}
	if multiplayer.is_server():
		_receive_registration.rpc(data)
	else:
		_receive_registration.rpc_id(1, data)

@rpc("any_peer", "reliable", "call_local")
func _receive_registration(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = 1
	data["peer_id"] = peer_id
	connected_players[peer_id] = data
	# Broadcast updated list to everyone
	_sync_player_list.rpc(connected_players)

@rpc("authority", "reliable", "call_local")
func _sync_player_list(all_players: Dictionary) -> void:
	var prev_ids := connected_players.keys()
	connected_players = all_players
	for pid in all_players:
		if not pid in prev_ids:
			player_joined.emit(pid, all_players[pid])

# ── Multiplayer callbacks ──────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	connected_players.erase(id)
	player_left.emit(id)

func _on_connected_to_server() -> void:
	connected_to_host.emit()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	is_hosting = false
	connected_players.clear()
	host_disconnected.emit()
