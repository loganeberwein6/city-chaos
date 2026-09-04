extends Node3D

signal world_ready()

enum TileType { RESIDENTIAL, COMMERCIAL, INDUSTRIAL, PARK, EMPTY }

const BLOCK_SIZE   := 40.0   # metres per city block
const ROAD_WIDTH   := 8.0    # metres
const CELL_STRIDE  := BLOCK_SIZE + ROAD_WIDTH  # block + road between them
const BUILDING_MARGIN := 2.0

const GRID_SIZES := {"small": 4, "medium": 7, "large": 11}

var _rng    := RandomNumberGenerator.new()
var _grid   := []   # 2D array of TileType
var _grid_n := 7
var seed_value: int = 0

# Materials (placeholder colours, replace with textures later)
var _mat_road        : StandardMaterial3D
var _mat_sidewalk    : StandardMaterial3D
var _mat_grass       : StandardMaterial3D
var _mat_residential : StandardMaterial3D
var _mat_commercial  : StandardMaterial3D
var _mat_industrial  : StandardMaterial3D

func _ready() -> void:
	_build_materials()

func generate(world_seed: int, map_size: String) -> void:
	seed_value  = world_seed
	_grid_n     = GRID_SIZES.get(map_size, 7)
	_rng.seed   = world_seed
	_grid       = []

	for x in _grid_n:
		_grid.append([])
		for z in _grid_n:
			_grid[x].append(_pick_tile_type(x, z))

	_build_ground()
	_build_roads()
	_build_blocks()
	_place_spawn_points()
	world_ready.emit()

# ── Tile logic ─────────────────────────────────────────────────────────────────

func _pick_tile_type(x: int, z: int) -> TileType:
	# Edges tend to be industrial, centre commercial, rest residential with parks
	var cx: int = _grid_n / 2
	var dist: int = absi(x - cx) + absi(z - cx)
	var roll := _rng.randf()
	if dist <= 1:
		return TileType.COMMERCIAL if roll < 0.7 else TileType.PARK
	elif dist >= _grid_n / 2:
		return TileType.INDUSTRIAL if roll < 0.6 else TileType.RESIDENTIAL
	else:
		if roll < 0.55:   return TileType.RESIDENTIAL
		elif roll < 0.75: return TileType.COMMERCIAL
		elif roll < 0.85: return TileType.INDUSTRIAL
		else:             return TileType.PARK

# ── Ground plane ───────────────────────────────────────────────────────────────

func _build_ground() -> void:
	var total := _grid_n * CELL_STRIDE + ROAD_WIDTH
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(total, total)
	mesh.material = _mat_sidewalk
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(total * 0.5 - ROAD_WIDTH * 0.5, 0.0, total * 0.5 - ROAD_WIDTH * 0.5)
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(total + 100.0, 0.2, total + 100.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(total * 0.5 - ROAD_WIDTH * 0.5, -0.1, total * 0.5 - ROAD_WIDTH * 0.5)
	add_child(body)

# ── Roads ──────────────────────────────────────────────────────────────────────

func _build_roads() -> void:
	var total := _grid_n * CELL_STRIDE + ROAD_WIDTH
	# Horizontal strips
	for z in _grid_n + 1:
		var strip := _make_flat_box(
			Vector3(total, 0.02, ROAD_WIDTH),
			Vector3(total * 0.5 - ROAD_WIDTH * 0.5, 0.01, z * CELL_STRIDE),
			_mat_road)
		add_child(strip)
	# Vertical strips
	for x in _grid_n + 1:
		var strip := _make_flat_box(
			Vector3(ROAD_WIDTH, 0.02, total),
			Vector3(x * CELL_STRIDE, 0.01, total * 0.5 - ROAD_WIDTH * 0.5),
			_mat_road)
		add_child(strip)

# ── Blocks ─────────────────────────────────────────────────────────────────────

func _build_blocks() -> void:
	for x in _grid_n:
		for z in _grid_n:
			var tile: TileType = _grid[x][z]
			var origin := Vector3(
				x * CELL_STRIDE + ROAD_WIDTH,
				0.0,
				z * CELL_STRIDE + ROAD_WIDTH)
			match tile:
				TileType.RESIDENTIAL:  _build_residential(origin)
				TileType.COMMERCIAL:   _build_commercial(origin)
				TileType.INDUSTRIAL:   _build_industrial(origin)
				TileType.PARK:         _build_park(origin)

func _build_residential(origin: Vector3) -> void:
	var count := _rng.randi_range(3, 6)
	for i in count:
		var bw := _rng.randf_range(6.0, 12.0)
		var bh := _rng.randf_range(4.0, 18.0)
		var bd := _rng.randf_range(6.0, 12.0)
		var bx := _rng.randf_range(BUILDING_MARGIN, BLOCK_SIZE - bw - BUILDING_MARGIN)
		var bz := _rng.randf_range(BUILDING_MARGIN, BLOCK_SIZE - bd - BUILDING_MARGIN)
		var building := _make_building(Vector3(bw, bh, bd), origin + Vector3(bx, 0, bz), _mat_residential)
		add_child(building)

func _build_commercial(origin: Vector3) -> void:
	var count := _rng.randi_range(1, 3)
	for i in count:
		var bw := _rng.randf_range(10.0, 20.0)
		var bh := _rng.randf_range(15.0, 50.0)
		var bd := _rng.randf_range(10.0, 20.0)
		var bx := _rng.randf_range(BUILDING_MARGIN, BLOCK_SIZE - bw - BUILDING_MARGIN)
		var bz := _rng.randf_range(BUILDING_MARGIN, BLOCK_SIZE - bd - BUILDING_MARGIN)
		var building := _make_building(Vector3(bw, bh, bd), origin + Vector3(bx, 0, bz), _mat_commercial)
		add_child(building)

func _build_industrial(origin: Vector3) -> void:
	var bw := _rng.randf_range(15.0, BLOCK_SIZE - BUILDING_MARGIN * 2)
	var bh := _rng.randf_range(6.0, 14.0)
	var bd := _rng.randf_range(15.0, BLOCK_SIZE - BUILDING_MARGIN * 2)
	bw = minf(bw, BLOCK_SIZE - BUILDING_MARGIN * 2)
	bd = minf(bd, BLOCK_SIZE - BUILDING_MARGIN * 2)
	var building := _make_building(Vector3(bw, bh, bd), origin + Vector3(BUILDING_MARGIN, 0, BUILDING_MARGIN), _mat_industrial)
	add_child(building)

func _build_park(origin: Vector3) -> void:
	var ground := _make_flat_box(
		Vector3(BLOCK_SIZE, 0.05, BLOCK_SIZE),
		origin + Vector3(BLOCK_SIZE * 0.5, 0.025, BLOCK_SIZE * 0.5),
		_mat_grass)
	add_child(ground)
	# A few trees (placeholder cylinders)
	for i in _rng.randi_range(4, 10):
		var tx := _rng.randf_range(2.0, BLOCK_SIZE - 2.0)
		var tz := _rng.randf_range(2.0, BLOCK_SIZE - 2.0)
		var trunk := _make_cylinder(0.4, 3.0, origin + Vector3(tx, 1.5, tz), _mat_industrial)
		add_child(trunk)

# ── Spawn points ───────────────────────────────────────────────────────────────

func _place_spawn_points() -> void:
	# One per road intersection
	for x in _grid_n + 1:
		for z in _grid_n + 1:
			if (x + z) % 3 != 0:
				continue
			var pos := Vector3(x * CELL_STRIDE + ROAD_WIDTH * 0.5, 1.0, z * CELL_STRIDE + ROAD_WIDTH * 0.5)
			GameManager.register_spawn_point(pos)

# ── Mesh helpers ───────────────────────────────────────────────────────────────

func _make_building(size: Vector3, origin: Vector3, mat: StandardMaterial3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mi   := MeshInstance3D.new()
	var box  := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = mi.position
	body.add_child(mi)
	body.add_child(cs)
	body.position = origin
	return body

func _make_flat_box(size: Vector3, center: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = center
	return mi

func _make_cylinder(radius: float, height: float, center: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = radius
	cyl.bottom_radius = radius
	cyl.height        = height
	cyl.material      = mat
	mi.mesh     = cyl
	mi.position = center
	return mi

# ── Materials ──────────────────────────────────────────────────────────────────

func _build_materials() -> void:
	_mat_road        = _solid_mat(Color(0.18, 0.18, 0.18))
	_mat_sidewalk    = _solid_mat(Color(0.55, 0.53, 0.50))
	_mat_grass       = _solid_mat(Color(0.25, 0.52, 0.20))
	_mat_residential = _solid_mat(Color(0.72, 0.65, 0.55))
	_mat_commercial  = _solid_mat(Color(0.55, 0.65, 0.78))
	_mat_industrial  = _solid_mat(Color(0.50, 0.48, 0.45))

func _solid_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = 0.85
	m.metallic     = 0.0
	return m
