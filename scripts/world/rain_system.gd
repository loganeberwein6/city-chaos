extends Node3D

var _active := false
var _particles: GPUParticles3D

func _ready() -> void:
	_build_particles()
	set_process(false)
	add_to_group("rain_system")

func _build_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 2000
	_particles.lifetime = 1.2
	_particles.preprocess = 1.0
	_particles.fixed_fps = 30
	_particles.emit_unit = GPUParticles3D.EMIT_UNIT_DISABLED

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(40.0, 0.5, 40.0)
	mat.gravity = Vector3(0.0, -35.0, 0.0)
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 22.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 3.0
	mat.scale_min = 0.02
	mat.scale_max = 0.04
	var rain_color := Gradient.new()
	rain_color.add_point(0.0, Color(0.7, 0.8, 0.9, 0.0))
	rain_color.add_point(0.3, Color(0.7, 0.8, 0.9, 0.6))
	rain_color.add_point(1.0, Color(0.7, 0.8, 0.9, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = rain_color
	mat.color_ramp = color_tex
	_particles.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.02, 0.25)
	_particles.draw_pass_1 = mesh

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.albedo_color = Color(0.75, 0.85, 0.95, 0.5)
	mesh_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mesh_mat)

	_particles.emitting = false
	_particles.position = Vector3(0.0, 20.0, 0.0)
	add_child(_particles)

func _process(_delta: float) -> void:
	# Follow the local player's camera so rain always surrounds player
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.get("_is_local"):
			_particles.global_position = p.global_position + Vector3(0.0, 18.0, 0.0)
			break

func set_rain(enabled: bool) -> void:
	_active = enabled
	_particles.emitting = enabled
	set_process(enabled)
