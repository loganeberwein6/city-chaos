extends Node
# Lightweight HTTP matchmaker server — runs on port 7779 when activated.
# Hosts POST /register every few seconds; joiners GET /servers to list games.
# Source IP is auto-detected so hosts don't need to know their public IP.

const PORT      := 7779
const ENTRY_TTL := 20.0  # seconds before an entry is considered stale

var active := false

var _tcp    := TCPServer.new()
var _entries: Dictionary = {}  # "ip:port" -> info dict
var _clients: Array = []       # [{conn: StreamPeerTCP, buf: PackedByteArray}]

func _ready() -> void:
	set_process(false)

func start() -> void:
	var err := _tcp.listen(PORT)
	if err != OK:
		push_error("Matchmaker: cannot listen on port %d: %s" % [PORT, error_string(err)])
		return
	active = true
	set_process(true)
	print("Matchmaker listening on port %d" % PORT)

func stop() -> void:
	for c in _clients:
		(c["conn"] as StreamPeerTCP).disconnect_from_host()
	_clients.clear()
	_entries.clear()
	_tcp.stop()
	active = false
	set_process(false)

func entry_count() -> int:
	return _entries.size()

func _process(_delta: float) -> void:
	# Accept new TCP connections
	while _tcp.is_connection_available():
		_clients.append({"conn": _tcp.take_connection(), "buf": PackedByteArray()})

	# Expire stale game entries
	var now := Time.get_unix_time_from_system()
	for key in _entries.keys():
		if now - _entries[key].get("seen", 0.0) > ENTRY_TTL:
			_entries.erase(key)

	# Service each client
	var dead: Array = []
	for c in _clients:
		var conn: StreamPeerTCP = c["conn"]
		conn.poll()
		var st := conn.get_status()
		if st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
			dead.append(c)
			continue
		var n := conn.get_available_bytes()
		if n > 0:
			var res := conn.get_data(n)
			if res[0] == OK:
				(c["buf"] as PackedByteArray).append_array(res[1] as PackedByteArray)
			_try_serve(c)
		if conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			dead.append(c)
	for c in dead:
		_clients.erase(c)

func _try_serve(c: Dictionary) -> void:
	var buf := c["buf"] as PackedByteArray
	var text := buf.get_string_from_utf8()
	var sep := text.find("\r\n\r\n")
	if sep == -1:
		return  # incomplete request

	var header := text.substr(0, sep)
	var lines  := header.split("\r\n")
	var req    := lines[0].split(" ")
	var method := req[0] if req.size() > 0 else ""
	var path   := req[1] if req.size() > 1 else "/"

	var content_length := 0
	for line in lines:
		if line.to_lower().begins_with("content-length:"):
			content_length = line.split(":")[1].strip_edges().to_int()

	var body_start := sep + 4
	if buf.size() < body_start + content_length:
		return  # body not fully received yet

	var body := buf.slice(body_start, body_start + content_length).get_string_from_utf8()
	c["buf"] = PackedByteArray()

	var conn: StreamPeerTCP = c["conn"]
	var remote_ip := conn.get_connected_host()
	var resp := _handle(method, path, body, remote_ip)
	conn.put_data(resp.to_utf8_buffer())
	conn.disconnect_from_host()

func _handle(method: String, path: String, body: String, remote_ip: String) -> String:
	if method == "GET" and path == "/servers":
		var list := JSON.stringify(_entries.values())
		return "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [list.length(), list]

	if method == "POST" and path == "/register":
		var data = JSON.parse_string(body)
		if data is Dictionary:
			var port: int = data.get("port", 7777)
			var key := "%s:%d" % [remote_ip, port]
			data["ip"]   = remote_ip   # use actual connection IP, not what client claims
			data["seen"] = Time.get_unix_time_from_system()
			_entries[key] = data
			return "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
		return "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"

	return "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
