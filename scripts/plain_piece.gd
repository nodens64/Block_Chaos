class_name PlainPiece
extends RigidBody3D
## 평원에 놓인 블록. 평소에는 고정이고, 대포로 날아가는 동안에만 물리가 켜진다.

var kind := 0
var color := Color.WHITE
var flying := false
var marked := false        # 블록 표시 스킬로 빛나는 중
var _rest := 0.0
var _fly := 0.0
var _meshes: Array = []

func setup(k: int, c: Color, offsets: Array, cell: float) -> void:
	kind = k
	color = c
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	set_physics_process(false)
	for o in offsets:
		var cs := CollisionShape3D.new()
		cs.shape = Blocks.box_shape(cell)
		cs.position = Vector3(o) * cell
		add_child(cs)
		var mi := Blocks.cell_mesh(cell, c)
		mi.position = cs.position
		add_child(mi)
		_meshes.append(mi)

func launch(vel: Vector3, ang: Vector3) -> void:
	freeze = false
	flying = true
	_rest = 0.0
	_fly = 0.0
	linear_velocity = vel
	angular_velocity = ang
	set_physics_process(true)

func set_glow(v: float) -> void:
	for mi in _meshes:
		mi.set_instance_shader_parameter("glow", v)

func _physics_process(d: float) -> void:
	_fly += d
	if linear_velocity.length() < 0.2 and angular_velocity.length() < 0.4:
		_rest += d
	else:
		_rest = 0.0
	if position.y < -3.0:
		position.y = 2.0
		linear_velocity = Vector3.ZERO
	if _rest > 0.35 or _fly > 12.0:
		flying = false
		freeze = true
		set_physics_process(false)
