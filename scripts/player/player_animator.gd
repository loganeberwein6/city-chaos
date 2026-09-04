extends Node

var _mesh_root: Node3D

# Limb node refs (found by name after model is built)
var _rua: Node3D    # right upper arm
var _lua: Node3D    # left upper arm
var _rla: Node3D    # right lower arm
var _lla: Node3D    # left lower arm
var _rhand: Node3D  # right hand
var _rul: Node3D    # right upper leg
var _lul: Node3D    # left upper leg
var _rll: Node3D    # right lower leg
var _lll: Node3D    # left lower leg
var _torso: Node3D

# Rest positions for punch reset
var _rla_rest_pos := Vector3.ZERO
var _rhand_rest_pos := Vector3.ZERO

var _anim_t     := 0.0
var _speed      := 0.0
var _is_punching := false

func setup(mesh_root: Node3D) -> void:
	_mesh_root = mesh_root
	_refresh()

func _refresh() -> void:
	if not _mesh_root:
		return
	_rua   = _mesh_root.get_node_or_null("RUA")
	_lua   = _mesh_root.get_node_or_null("LUA")
	_rla   = _mesh_root.get_node_or_null("RLA")
	_lla   = _mesh_root.get_node_or_null("LLA")
	_rhand = _mesh_root.get_node_or_null("RHand")
	_rul   = _mesh_root.get_node_or_null("RUL")
	_lul   = _mesh_root.get_node_or_null("LUL")
	_rll   = _mesh_root.get_node_or_null("RLL")
	_lll   = _mesh_root.get_node_or_null("LLL")
	_torso = _mesh_root.get_node_or_null("Torso")
	# Cache rest positions so punch can return to them
	if _rla:   _rla_rest_pos   = _rla.position
	if _rhand: _rhand_rest_pos = _rhand.position

func set_speed(speed: float) -> void:
	_speed = speed

func _process(delta: float) -> void:
	if not _mesh_root:
		return
	if not _rua:
		_refresh()
		return

	# Tick the animation clock — always runs so idle breath plays even while still
	_anim_t += delta * maxf(_speed * 1.5, 0.9)
	var t    := _anim_t
	var spd  := _speed

	# Amplitude scales with movement speed (zero at idle = very small oscillation)
	var arm_amp := clampf(spd * 0.055, 0.04, 0.50)
	var leg_amp := clampf(spd * 0.050, 0.04, 0.45)

	# Right leg forward → left arm forward (opposite sides in phase)
	# rotation.x negative = forward swing for a Y-axis capsule
	if _rul: _rul.rotation.x = -sin(t) * leg_amp
	if _lul: _lul.rotation.x =  sin(t) * leg_amp
	if _rll: _rll.rotation.x = maxf(-sin(t), 0.0) * leg_amp * 0.5
	if _lll: _lll.rotation.x = maxf( sin(t), 0.0) * leg_amp * 0.5
	if _lua: _lua.rotation.x = -sin(t) * arm_amp
	if _lla: _lla.rotation.x = -sin(t) * arm_amp * 0.4

	# Right arm only when not mid-punch
	if not _is_punching:
		if _rua: _rua.rotation.x =  sin(t) * arm_amp

	# Gentle idle torso breath
	if _torso:
		_torso.position.y = 1.28 + sin(t * 0.4) * 0.006

func play_punch() -> void:
	if _is_punching or not _rua or not _rla or not _rhand:
		return
	_is_punching = true

	var tween := _rua.create_tween()
	tween.set_parallel(true)

	# Phase 1: 0.09 s — swing upper arm forward, extend lower arm & hand
	tween.tween_property(_rua,   "rotation:x",  -1.15, 0.09)
	tween.tween_property(_rla,   "position:z",   _rla_rest_pos.z   - 0.28, 0.09)
	tween.tween_property(_rhand, "position:z",   _rhand_rest_pos.z - 0.28, 0.09)

	# Phase 2: 0.20 s — return
	tween.chain().set_parallel(true)
	tween.tween_property(_rua,   "rotation:x",   0.0,               0.20)
	tween.tween_property(_rla,   "position:z",   _rla_rest_pos.z,   0.20)
	tween.tween_property(_rhand, "position:z",   _rhand_rest_pos.z, 0.20)

	tween.chain().tween_callback(func() -> void: _is_punching = false)
