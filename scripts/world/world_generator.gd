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
	_place_lampposts()
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
	# Centerline dashes
	var white_mat := _solid_mat(Color(0.92, 0.92, 0.88))
	var dash_count: int = int(total / 6.0)
	# Horizontal road centerlines
	for z in _grid_n + 1:
		var road_z: float = z * CELL_STRIDE
		for d in dash_count:
			if d % 2 == 0:
				continue
			var dx: float = d * 6.0 + 1.0
			var dash := _make_flat_box(Vector3(3.5, 0.03, 0.18), Vector3(dx, 0.03, road_z), white_mat)
			add_child(dash)
	# Vertical road centerlines
	for x in _grid_n + 1:
		var road_x: float = x * CELL_STRIDE
		for d in dash_count:
			if d % 2 == 0:
				continue
			var dz: float = d * 6.0 + 1.0
			var dash := _make_flat_box(Vector3(0.18, 0.03, 3.5), Vector3(road_x, 0.03, dz), white_mat)
			add_child(dash)

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
	# Central path
	var path_mat := _solid_mat(Color(0.62, 0.58, 0.52))
	var path := _make_flat_box(
		Vector3(2.0, 0.06, BLOCK_SIZE),
		origin + Vector3(BLOCK_SIZE * 0.5, 0.03, BLOCK_SIZE * 0.5),
		path_mat)
	add_child(path)
	# Benches
	var bench_mat := _solid_mat(Color(0.4, 0.28, 0.15))
	for _i in 3:
		var bx: float = _rng.randf_range(3.0, BLOCK_SIZE - 3.0)
		var bz: float = _rng.randf_range(3.0, BLOCK_SIZE - 3.0)
		var seat := _make_flat_box(
			Vector3(1.4, 0.08, 0.45),
			origin + Vector3(bx, 0.45, bz),
			bench_mat)
		add_child(seat)
		var back := _make_flat_box(
			Vector3(1.4, 0.5, 0.08),
			origin + Vector3(bx, 0.7, bz - 0.2),
			bench_mat)
		add_child(back)

# ── Spawn points ───────────────────────────────────────────────────────────────

func _place_spawn_points() -> void:
	# One per road intersection
	for x in _grid_n + 1:
		for z in _grid_n + 1:
			if (x + z) % 3 != 0:
				continue
			var pos := Vector3(x * CELL_STRIDE + ROAD_WIDTH * 0.5, 1.0, z * CELL_STRIDE + ROAD_WIDTH * 0.5)
			GameManager.register_spawn_point(pos)

# ── Lampposts ──────────────────────────────────────────────────────────────────

func _place_lampposts() -> void:
	var pole_mat  := _solid_mat(Color(0.3, 0.3, 0.3))
	var light_mat := _solid_mat(Color(1.0, 0.95, 0.7))
	for x in _grid_n + 1:
		for z in _grid_n + 1:
			var pos := Vector3(
				x * CELL_STRIDE + ROAD_WIDTH * 0.5 - 1.5,
				0.0,
				z * CELL_STRIDE + ROAD_WIDTH * 0.5 - 1.5)
			var pole := _make_cylinder(0.08, 5.0, pos + Vector3(0.0, 2.5, 0.0), pole_mat)
			add_child(pole)
			var lamp := _make_flat_box(Vector3(0.4, 0.15, 0.4), pos + Vector3(0.0, 5.1, 0.0), light_mat)
			add_child(lamp)

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
	# Window bands: one horizontal strip per floor on front/back faces
	var win_mat := _solid_mat(Color(0.4, 0.55, 0.72))
	var floors: int = max(1, int(size.y / 3.5))
	for fl in floors:
		var wy: float = fl * 3.5 + 1.5
		if wy >= size.y:
			break
		var band := _make_flat_box(
			Vector3(size.x * 0.85, 0.8, 0.1),
			Vector3(size.x * 0.5, wy, size.z + 0.05),
			win_mat)
		body.add_child(band)
		var band2 := _make_flat_box(
			Vector3(size.x * 0.85, 0.8, 0.1),
			Vector3(size.x * 0.5, wy, -0.05),
			win_mat)
		body.add_child(band2)
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
	_mat_road        = _solid_mat(Color(0.14, 0.14, 0.14), 0.0, 0.95)
	_mat_sidewalk    = _solid_mat(Color(0.60, 0.57, 0.53), 0.0, 0.90)
	_mat_grass       = _solid_mat(Color(0.22, 0.50, 0.18), 0.0, 1.0)
	_mat_residential = _solid_mat(Color(0.75, 0.67, 0.55), 0.0, 0.85)
	_mat_commercial  = _solid_mat(Color(0.50, 0.62, 0.76), 0.1, 0.6)
	_mat_industrial  = _solid_mat(Color(0.48, 0.46, 0.42), 0.2, 0.7)

func _solid_mat(color: Color, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	m.metallic     = metallic
	return m
