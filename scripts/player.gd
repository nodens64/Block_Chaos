class_name Player
extends CharacterBody3D

const SPEED := 6.0
const JUMP := 6.0
const GRAV := 18.0
const STEP := 0.55
const JET_TIME := 3.0
const JET_COOLDOWN := 10.0

var cam: Camera3D
var active := true
var pitch := 0.0
var speed_mult := 1.0
var jump_mult := 1.0       # 점프 속도 배율 (높이 배율의 제곱근)
var jet_unlocked := false
var jet_t := 0.0           # 남은 비행 시간
var jet_cd := 0.0          # 남은 재사용 대기

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.55
	cam.fov = 75
	add_child(cam)
	cam.current = true
	floor_snap_length = 0.3

func _unhandled_input(e: InputEvent) -> void:
	if active and e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * 0.0025)
		pitch = clamp(pitch - e.relative.y * 0.0025, -1.5, 1.5)
		cam.rotation.x = pitch

func _physics_process(d: float) -> void:
	var dir := Vector3.ZERO
	if active:
		var iv := Input.get_vector("left", "right", "fwd", "back")
		dir = transform.basis * Vector3(iv.x, 0, iv.y)
		dir.y = 0
		dir = dir.normalized()
	velocity.x = dir.x * SPEED * speed_mult
	velocity.z = dir.z * SPEED * speed_mult

	jet_cd = max(0.0, jet_cd - d)
	if active and jet_unlocked and jet_cd <= 0.0 and Input.is_action_just_pressed("jet"):
		jet_t = JET_TIME
		jet_cd = JET_COOLDOWN
	var on_floor := is_on_floor()
	if jet_t > 0.0:
		# 비행 중에는 중력이 없다. Space로 올라간다.
		jet_t -= d
		if active and Input.is_action_pressed("jump"):
			velocity.y = 5.0
		else:
			velocity.y = move_toward(velocity.y, 0.0, 30.0 * d)
	elif on_floor:
		if active and Input.is_action_pressed("jump"):
			velocity.y = JUMP * jump_mult
	else:
		velocity.y -= GRAV * d
	move_and_slide()
	# 블록 한 칸 높이는 점프 없이 올라간다.
	if on_floor and dir != Vector3.ZERO and is_on_wall():
		var up := Vector3.UP * STEP
		if not test_move(global_transform, up) \
				and not test_move(global_transform.translated(up), dir * 0.3):
			global_position += up + dir * 0.12
