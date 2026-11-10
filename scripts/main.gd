extends Node3D
## 싱글 플레이 핵심 루프: 평원에서 줍기 → 투입구 → 벨트 → 거대 격자 → 줄 완성 / 반송구 / 넘침.
## 스킬은 조종석에 앉아서만 투자한다.

const CELL := 0.5            # 평원 블록 한 칸 (m)
const GCELL := 2.0           # 거대 격자 한 칸 (m)
const GRID_Z := -36.0
const GRID_Y := 3.0
const SEAT_POS := Vector3(0, 0.5, -19.5)
const BELT_Y := 1.2
const BELT_Z := -27.0
const BELT_FRONT_X := -3.0
const BELT_STEP := 1.9
const BELT_SLOTS := 6        # 벨트에 보이는 블록 수. 나머지는 투입구 안에서 기다린다.
const BCELL := 0.35          # 벨트 위 블록 한 칸 (m)
const INTAKE_POS := Vector3(8.6, 0, -26.0)
const HOLD_POS := Vector3(-5.4, 2.4, -27.0)
const ROBOT_HOME := Vector3(5.6, 1.0, -22.5)
const HILL_N := 64
const HILL_ORIGIN := Vector3(-16, 0, -6)
const THEME_COLOR := Color(0.36, 0.62, 0.25)
const MAX_SP := 83
const REACH := 4.5
const CARRY_CAPS := [1, 2, 4, 6, 8, 10]
const ROBOT_PCT := [0.5, 0.65, 0.8]

const SKILLS := [
	{"id": "speed", "name": "이동 속도", "role": "수집가", "costs": [1, 2, 3],
		"desc": "단계마다 +20%. 수집 로봇도 같이 빨라진다"},
	{"id": "jump", "name": "점프력", "role": "수집가", "costs": [1, 2],
		"desc": "단계마다 점프 높이 +25%"},
	{"id": "jet", "name": "제트팩", "role": "수집가", "costs": [3],
		"desc": "F: 3초 동안 비행, 재사용 대기 10초"},
	{"id": "mark", "name": "블록 표시", "role": "수집가", "costs": [2],
		"desc": "주운 블록과 같은 종류가 10초 동안 빛난다"},
	{"id": "carry", "name": "다중 운반", "role": "수집가", "costs": [1, 1, 2, 2, 3],
		"desc": "드는 블록 1 → 2 → 4 → 6 → 8 → 10개. X로 넣을 순서 바꾸기"},
	{"id": "tidy", "name": "정리 내려놓기", "role": "수집가", "costs": [2],
		"desc": "G: 든 블록을 차곡차곡 쌓아 내려놓는다"},
	{"id": "robot", "name": "수집 로봇", "role": "수집 보조", "costs": [3],
		"desc": "무작위 블록을 주워 투입구에 넣는다. E로 켜고 끈다"},
	{"id": "robot_speed", "name": "로봇 가속", "role": "수집 보조", "costs": [2, 3],
		"desc": "로봇 속도 50% → 65% → 80%"},
	{"id": "intake", "name": "투입구 확장", "role": "공용", "costs": [1, 1, 2, 2, 3],
		"desc": "용량 +5 (최대 30)"},
	{"id": "laser", "name": "조준 레이저", "role": "조종사", "costs": [1, 3],
		"desc": "Lv.1 떨어질 열 표시, Lv.2 착지점이 빛난다"},
	{"id": "hard", "name": "하드 드롭", "role": "조종사", "costs": [2],
		"desc": "Space: 블록을 바로 떨어뜨린다"},
	{"id": "soft", "name": "하강 속도", "role": "조종사", "costs": [1, 2, 3],
		"desc": "S로 내리는 속도 단계마다 +30%"},
	{"id": "side", "name": "좌우 이동 속도", "role": "조종사", "costs": [1, 2, 3],
		"desc": "집게 좌우 이동 단계마다 +30%"},
	{"id": "ease", "name": "중력 완화", "role": "조종사", "costs": [2, 3, 4],
		"desc": "빨라진 자동 하강을 단계마다 15% 늦춘다"},
	{"id": "grid", "name": "격자 확장", "role": "조종사", "costs": [2, 2, 3, 3, 4],
		"desc": "가로 +1, 세로 +2 (최대 10×15)"},
]

var total_blocks := 2000
var grid := GridLogic.new(5, 5)
var player: Player
var seat_cam: Camera3D
var seated := false

var carried: Array = []      # 든 블록 {kind, color}. 0번이 맨 아래이고 먼저 들어간다.
var carried_vis: Node3D
var queue: Array = []        # 투입구~벨트에 있는 블록 {kind, color, node}
var held = null              # 홀드 집게가 든 블록 {kind, color, node}
var intake_cap := 5
var inserted := 0
var total := 0
var plain_count := 0
var init_cells := 0
var elapsed := 0.0
var cleared := false

var levels := {}             # 스킬 id -> 단계
var sp := 0                  # 쓸 수 있는 포인트
var sp_earned := 0           # 지금까지 얻은 포인트
var sp_lines := 0.0
var menu_open := false
var menu_sel := 0

var feeding := false         # 벨트에서 격자로 블록이 흐르는 중인지
var fall_t := 0.0
var spawn_cd := 0.0
var move_t := 0.0
var soft_t := 0.0
var insert_cd := 0.0
var hover: PlainPiece
var marked: Array = []
var mark_t := 0.0
var cannon_queue: Array = []
var cannon_t := 0.0

var robot: AnimatableBody3D
var robot_on := false
var robot_target: PlainPiece
var robot_cargo = null
var robot_cargo_vis: Node3D

var pool: Array = []
var fx_pool: Array = []
var beam_mat: StandardMaterial3D
var ghost_mat: StandardMaterial3D
var grid_root: Node3D
var frame: Node3D
var claw: MeshInstance3D
var ground_mat: ShaderMaterial
var pieces_root: Node3D
var belt_root: Node3D

var l_counter: Label
var l_score: Label
var l_gain: Label
var l_time: Label
var l_prompt: Label
var l_help: Label
var l_msg: Label
var l_sp: Label
var l_status: Label
var sp_bar: ProgressBar
var cross: ColorRect
var clear_panel: Label
var menu_bg: ColorRect
var menu_text: RichTextLabel
var gain_t := 0.0
var msg_t := 0.0

var shot_path := ""
var shot_frames := 90
var frame_no := 0
var debug_seat := false
var debug_menu := false
var debug_yaw := 0.0
var debug_buy: Array = []

func _ready() -> void:
	randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--blocks="):
			total_blocks = int(a.get_slice("=", 1))
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
		elif a.begins_with("--frames="):
			shot_frames = int(a.get_slice("=", 1))
		elif a.begins_with("--sp="):
			sp = int(a.get_slice("=", 1))
		elif a.begins_with("--buy="):
			debug_buy = a.get_slice("=", 1).split(",")
		elif a == "--seat":
			debug_seat = true
		elif a == "--menu":
			debug_menu = true
		elif a.begins_with("--yaw="):
			debug_yaw = float(a.get_slice("=", 1))
	_setup_input()
	_build_world()
	_build_structures()
	grid_root = Node3D.new()
	add_child(grid_root)
	_build_frame()
	pieces_root = Node3D.new()
	add_child(pieces_root)
	_gen_hill(total_blocks)
	total = total_blocks
	plain_count = total_blocks
	player = Player.new()
	player.position = Vector3(0, 0.1, -12)
	player.rotation_degrees.y = debug_yaw
	add_child(player)
	_build_hud()
	grid.locked.connect(_on_locked)
	grid.overflowed.connect(_on_overflowed)
	grid.returned.connect(_on_returned)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for id in debug_buy:
		for i in SKILLS.size():
			if SKILLS[i].id == id:
				_buy(i)
	if robot != null and not debug_buy.is_empty():
		robot_on = true
	if debug_seat:
		for i in 5:
			_enqueue(randi() % Shapes.COUNT, Shapes.random_color())
		inserted = 5
		plain_count -= 5
		_sit()
		if debug_menu:
			menu_open = true
			_refresh_menu()

# ---------------------------------------------------------------- 준비

func _setup_input() -> void:
	_action("left", [KEY_A, KEY_LEFT])
	_action("right", [KEY_D, KEY_RIGHT])
	_action("fwd", [KEY_W, KEY_UP])
	_action("back", [KEY_S, KEY_DOWN])
	_action("jump", [KEY_SPACE])
	_action("interact", [KEY_E])
	_action("drop", [KEY_Q])
	_action("hold", [KEY_C])
	_action("rot_ccw", [KEY_Z])
	_action("chute", [KEY_R])
	_action("skills", [KEY_TAB])
	_action("buy", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	_action("jet", [KEY_F])
	_action("cycle", [KEY_X])
	_action("tidy", [KEY_G])
	InputMap.add_action("grab")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("grab", mb)

func _action(action: String, keys: Array) -> void:
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	add_child(sun)

	var sh := Shader.new()
	sh.code = "
shader_type spatial;
uniform float radius = 0.0;
uniform vec3 center = vec3(0.0);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = distance(wp.xz, center.xz);
	float m = smoothstep(radius, radius - 1.5, d);
	vec2 g = abs(fract(wp.xz * 2.0) - 0.5);
	float line = step(0.46, max(g.x, g.y));
	vec3 mach = mix(vec3(0.21, 0.22, 0.27), vec3(0.11, 0.12, 0.16), line);
	ALBEDO = mix(mach, vec3(0.33, 0.58, 0.24), m);
	ROUGHNESS = 0.9;
}
"
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = sh
	ground_mat.set_shader_parameter("center", Vector3(0, 0, -14))
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(200, 1, 200)
	gs.shape = gb
	gs.position.y = -0.5
	ground.add_child(gs)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	pm.material = ground_mat
	gm.mesh = pm
	ground.add_child(gm)
	add_child(ground)

	beam_mat = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(1.0, 0.2, 0.2)
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.28)

func _box(pos: Vector3, size: Vector3, color: Color, collide := true, tag := "") -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	bm.material = mat
	mi.mesh = bm
	if not collide:
		mi.position = pos
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.add_child(mi)
	if tag != "":
		body.set_meta("tag", tag)
	return body

func _build_structures() -> void:
	# 조종석
	add_child(_box(SEAT_POS + Vector3(0, -0.25, 0), Vector3(6, 0.5, 4), Color(0.3, 0.32, 0.38)))
	add_child(_box(SEAT_POS + Vector3(0, 0.55, 0.3), Vector3(1.1, 1.1, 1.1), Color(0.85, 0.55, 0.2), true, "seat"))
	add_child(_box(SEAT_POS + Vector3(0, 0.35, -1.2), Vector3(2.4, 0.7, 0.5), Color(0.2, 0.22, 0.26)))
	seat_cam = Camera3D.new()
	add_child(seat_cam)
	# 벨트
	add_child(_box(Vector3(1.6, BELT_Y - 0.15, BELT_Z), Vector3(13.4, 0.3, 1.3), Color(0.13, 0.13, 0.15)))
	for x in [-4.5, 1.6, 7.6]:
		add_child(_box(Vector3(x, (BELT_Y - 0.3) / 2.0, BELT_Z), Vector3(0.4, BELT_Y - 0.3, 1.0), Color(0.25, 0.26, 0.3)))
	belt_root = Node3D.new()
	add_child(belt_root)
	# 투입구
	add_child(_box(INTAKE_POS + Vector3(0, 1.0, 0), Vector3(2.2, 2.0, 2.2), Color(0.75, 0.25, 0.55), true, "intake"))
	add_child(_box(INTAKE_POS + Vector3(0, 2.15, 0), Vector3(2.8, 0.3, 2.8), Color(0.95, 0.8, 0.25), true, "intake"))
	# 홀드 집게
	add_child(_box(HOLD_POS + Vector3(0, 1.75, 0), Vector3(0.25, 1.6, 0.25), Color(0.6, 0.62, 0.68), false))
	add_child(_box(HOLD_POS + Vector3(0, 0.95, 0), Vector3(1.8, 0.15, 0.6), Color(0.6, 0.62, 0.68), false))

func _build_frame() -> void:
	if frame:
		frame.queue_free()
	frame = Node3D.new()
	grid_root.add_child(frame)
	var gw := grid.w * GCELL
	var gh := grid.h * GCELL
	var dark := Color(0.08, 0.09, 0.12)
	var rim := Color(0.45, 0.47, 0.55)
	frame.add_child(_box(Vector3(0, GRID_Y + gh / 2.0, GRID_Z - 1.3), Vector3(gw, gh, 0.4), dark, false))
	frame.add_child(_box(Vector3(-gw / 2.0 - 0.4, GRID_Y + gh / 2.0, GRID_Z), Vector3(0.8, gh, 2.4), rim, false))
	frame.add_child(_box(Vector3(gw / 2.0 + 0.4, GRID_Y + gh / 2.0, GRID_Z), Vector3(0.8, gh, 2.4), rim, false))
	frame.add_child(_box(Vector3(0, GRID_Y - 0.4, GRID_Z), Vector3(gw + 1.6, 0.8, 2.4), rim, false))
	frame.add_child(_box(Vector3(0, (GRID_Y - 0.8) / 2.0, GRID_Z), Vector3(gw * 0.5, GRID_Y - 0.8, 2.0), dark, false))
	# 반송구 대포
	var cx := gw / 2.0 + 2.6
	frame.add_child(_box(Vector3(cx, GRID_Y + 0.6, GRID_Z), Vector3(3.2, 2.8, 2.4), Color(0.9, 0.45, 0.15), false))
	var barrel := _box(Vector3(cx, GRID_Y + 2.6, GRID_Z + 1.6), Vector3(1.4, 1.4, 4.0), Color(0.2, 0.2, 0.22), false)
	barrel.rotation_degrees.x = 35
	frame.add_child(barrel)
	if claw == null:
		claw = _box(Vector3.ZERO, Vector3(1.0, 0.5, 1.0), Color(0.75, 0.77, 0.82), false)
		grid_root.add_child(claw)
	_update_seat_cam()

func _update_seat_cam() -> void:
	var p := SEAT_POS + Vector3(0, 1.7, 0)
	var dist := p.z - GRID_Z
	var top := atan2(GRID_Y + grid.h * GCELL + 3.0 - p.y, dist)
	var bottom := deg_to_rad(-15.0)
	seat_cam.position = p
	seat_cam.rotation = Vector3((top + bottom) / 2.0, 0, 0)
	seat_cam.fov = clamp(rad_to_deg(top - bottom) + 6.0, 40.0, 110.0)

# ---------------------------------------------------------------- 평원

func _make_piece(kind: int, color: Color, offsets: Array) -> PlainPiece:
	var p := PlainPiece.new()
	p.setup(kind, color, offsets, CELL)
	return p

## 무작위 언덕. 블록을 위에서 떨어뜨려 쌓되, 목표 높이를 넘지 않는 자리만 받는다.
func _gen_hill(n: int) -> void:
	var hm := PackedInt32Array()
	hm.resize(HILL_N * HILL_N)
	var bumps := []
	for i in 5:
		bumps.append([randf_range(12, HILL_N - 12), randf_range(12, HILL_N - 12),
			randf_range(7, 12), randf_range(0.6, 1.0)])
	var target := PackedFloat32Array()
	target.resize(HILL_N * HILL_N)
	for z in HILL_N:
		for x in HILL_N:
			var t := 0.0
			for b in bumps:
				var d2: float = (x - b[0]) * (x - b[0]) + (z - b[1]) * (z - b[1])
				t += b[3] * exp(-d2 / (2.0 * b[2] * b[2]))
			target[z * HILL_N + x] = t
	var scale_h := 3.0
	var placed := 0
	var fails := 0
	while placed < n:
		var kind := randi() % Shapes.COUNT
		var cs: Array = Shapes.CELLS[kind]
		for r in randi() % 4:
			cs = Shapes.rotated(cs, 1)
		var mode := randi() % 3
		var c3 := []
		for c in cs:
			match mode:
				0: c3.append(Vector3i(c.x, 0, c.y))
				1: c3.append(Vector3i(c.x, c.y, 0))
				_: c3.append(Vector3i(0, c.y, c.x))
		var ox := randi_range(0, HILL_N - 4)
		var oz := randi_range(0, HILL_N - 4)
		var lows := {}
		var tops := {}
		for c in c3:
			var k := Vector2i(c.x, c.z)
			lows[k] = min(lows.get(k, 99), c.y)
			tops[k] = max(tops.get(k, -1), c.y)
		var base := 0
		for k in lows:
			base = max(base, hm[(oz + k.y) * HILL_N + ox + k.x] - lows[k])
		var ok := true
		for k in tops:
			if base + tops[k] + 1 > target[(oz + k.y) * HILL_N + ox + k.x] * scale_h:
				ok = false
				break
		if not ok:
			fails += 1
			if fails > 400:
				scale_h += 0.5
				fails = 0
			continue
		for k in tops:
			hm[(oz + k.y) * HILL_N + ox + k.x] = base + tops[k] + 1
		var p := _make_piece(kind, Shapes.random_color(), c3)
		p.position = HILL_ORIGIN + (Vector3(ox, base, oz) + Vector3(0.5, 0.5, 0.5)) * CELL
		pieces_root.add_child(p)
		init_cells += c3.size()
		placed += 1

# ---------------------------------------------------------------- 매 프레임

func _process(d: float) -> void:
	frame_no += 1
	if shot_path != "" and frame_no == shot_frames:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
		return
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if not cleared:
		elapsed += d
		grid.clock = elapsed
		_tick_grid(d)
		_tick_cannon(d)
		_tick_robot(d)
		_tick_mark(d)
		if seated:
			_seat_input(d)
		else:
			_walk_input(d)
		_check_clear()
	_tick_belt(d)
	_draw_grid()
	_update_hud(d)

func _lv(id: String) -> int:
	return levels.get(id, 0)

## 자동 하강 간격. 누적 점수 5,000점마다 10% 빨라지고, 중력 완화가 이를 늦춘다.
func fall_interval() -> float:
	var base: float = max(0.3, 1.5 * pow(0.9, floor(grid.score / 5000.0)))
	return min(1.5, base * (1.0 + 0.15 * _lv("ease")))

func _tick_grid(d: float) -> void:
	if grid.active == null:
		spawn_cd -= d
		if spawn_cd > 0.0:
			return
		if queue.is_empty():
			feeding = false
		elif seated or feeding:
			# 벨트가 비었다가 다시 채워지면 누가 조종석에 앉을 때까지 기다린다.
			# 한번 흐르기 시작하면 조종사가 일어나도 벨트가 빌 때까지 계속 나온다.
			feeding = true
			var q = queue.pop_front()
			q.node.queue_free()
			fall_t = 0.0
			if not grid.spawn(q.kind, q.color):
				spawn_cd = 1.0
	else:
		fall_t += d
		if fall_t >= fall_interval():
			fall_t = 0.0
			grid.step_down()

func _seat_input(d: float) -> void:
	if Input.is_action_just_pressed("skills"):
		menu_open = not menu_open
		_refresh_menu()
		return
	if menu_open:
		_menu_input()
		return
	if Input.is_action_just_pressed("interact"):
		_stand()
		return
	if Input.is_action_just_pressed("hold"):
		_hold()
	if grid.active == null:
		return
	var dx := int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	if Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right"):
		grid.move(dx)
		move_t = -0.2
	elif dx != 0:
		move_t += d
		if move_t >= 0.22 / (1.0 + 0.3 * _lv("side")):
			move_t = 0.0
			grid.move(dx)
	if Input.is_action_just_pressed("fwd"):
		grid.rotate(1)
	if Input.is_action_just_pressed("rot_ccw"):
		grid.rotate(-1)
	var soft := 0.18 / (1.0 + 0.3 * _lv("soft"))
	if Input.is_action_pressed("back"):
		soft_t += d
		if soft_t >= soft:
			soft_t = 0.0
			fall_t = 0.0
			grid.step_down()
	else:
		soft_t = soft
	if grid.active != null and Input.is_action_just_pressed("jump"):
		if _lv("hard") > 0:
			grid.hard_drop()
		else:
			_msg("하드 드롭은 스킬로 해금한다")
	if grid.active != null and Input.is_action_just_pressed("chute"):
		grid.send_to_chute()

func _walk_input(d: float) -> void:
	var cam := player.cam
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * REACH)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var col = hit.get("collider")
	var piece: PlainPiece = col as PlainPiece
	if piece != null and (piece.flying or piece.is_queued_for_deletion()):
		piece = null
	var cap: int = CARRY_CAPS[_lv("carry")]
	var room := carried.size() < cap
	if hover != piece:
		if is_instance_valid(hover):
			hover.set_glow(0.6 if hover.marked else 0.0)
		hover = piece
	if hover != null:
		hover.set_glow(0.35 if room else (0.6 if hover.marked else 0.0))
	var tag: String = col.get_meta("tag", "") if col != null else ""
	var act := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("grab")
	insert_cd -= d
	var prompt := ""
	if piece != null:
		if room:
			prompt = "[E] 줍기"
			if act:
				_pick(piece)
		else:
			prompt = "더 들 수 없다 · [Q] 내려놓기"
	elif tag == "intake":
		if carried.is_empty():
			prompt = "투입구 %d / %d" % [queue.size(), intake_cap]
		elif queue.size() >= intake_cap:
			prompt = "투입구가 가득 찼다 (%d / %d)" % [queue.size(), intake_cap]
		else:
			prompt = "[E] 투입구에 넣기"
			# 여러 개를 들었으면 E를 누르고 있는 동안 차례로 들어간다.
			if act or (Input.is_action_pressed("interact") and insert_cd <= 0.0):
				_insert()
				insert_cd = 0.18
	elif tag == "seat":
		prompt = "[E] 조종석에 앉기"
		if act:
			_sit()
	elif tag == "robot":
		prompt = "[E] 수집 로봇 끄기" if robot_on else "[E] 수집 로봇 켜기"
		if act:
			robot_on = not robot_on
	l_prompt.text = prompt
	if carried.is_empty():
		return
	if Input.is_action_just_pressed("drop"):
		_drop()
	elif Input.is_action_just_pressed("cycle") and carried.size() > 1:
		carried.append(carried.pop_front())
		_refresh_carried()
	elif Input.is_action_just_pressed("tidy") and _lv("tidy") > 0:
		_tidy_drop()

# ---------------------------------------------------------------- 수집

func _pick(piece: PlainPiece) -> void:
	carried.append({"kind": piece.kind, "color": piece.color})
	var kind := piece.kind
	piece.queue_free()
	hover = null
	plain_count -= 1
	_refresh_carried()
	if _lv("mark") > 0:
		_clear_marks()
		for p in pieces_root.get_children():
			if p.kind == kind and not p.is_queued_for_deletion():
				p.marked = true
				p.set_glow(0.6)
				marked.append(p)
		mark_t = 10.0

func _clear_marks() -> void:
	for p in marked:
		if is_instance_valid(p):
			p.marked = false
			p.set_glow(0.0)
	marked.clear()

func _tick_mark(d: float) -> void:
	if mark_t > 0.0:
		mark_t -= d
		if mark_t <= 0.0:
			_clear_marks()

func _refresh_carried() -> void:
	if carried_vis:
		carried_vis.queue_free()
		carried_vis = null
	if carried.is_empty():
		return
	carried_vis = Node3D.new()
	carried_vis.position = Vector3(0.6, -0.62, -1.0)
	carried_vis.rotation_degrees = Vector3(8, -20, 0)
	var size := 0.13 if carried.size() == 1 else 0.07
	var y := 0.0
	for c in carried:
		var v := Blocks.piece_visual(c.kind, size, c.color)
		v.position.y = y
		carried_vis.add_child(v)
		y += (Shapes.size(Shapes.CELLS[c.kind]).y + 0.25) * size
	player.cam.add_child(carried_vis)

func _drop() -> void:
	var c = carried.pop_back()
	var p := _make_piece(c.kind, c.color, Blocks.flat_offsets(c.kind))
	var fwd := -player.cam.global_transform.basis.z
	p.position = player.cam.global_position + fwd * 1.3
	pieces_root.add_child(p)
	p.launch(fwd * 4.0, Vector3.ZERO)
	plain_count += 1
	_refresh_carried()

## 든 블록을 전부 눈앞 바닥에 차곡차곡 쌓는다.
func _tidy_drop() -> void:
	var fwd := -player.global_transform.basis.z
	var at := player.global_position + fwd * 1.8
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 20.0)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var y: float = hit.position.y if hit.has("position") else 0.0
	for c in carried:
		var p := _make_piece(c.kind, c.color, Blocks.flat_offsets(c.kind))
		p.position = Vector3(at.x, y + CELL / 2.0, at.z)
		p.rotation.y = player.rotation.y
		pieces_root.add_child(p)
		y += CELL
	plain_count += carried.size()
	carried.clear()
	_refresh_carried()

func _insert() -> void:
	var c = carried.pop_front()
	_enqueue(c.kind, c.color)
	inserted += 1
	_refresh_carried()

func _enqueue(kind: int, color: Color) -> void:
	var node := Blocks.piece_visual(kind, BCELL, color)
	node.position = Vector3(INTAKE_POS.x - 1.0, BELT_Y, BELT_Z)
	belt_root.add_child(node)
	queue.append({"kind": kind, "color": color, "node": node})

func _tick_belt(d: float) -> void:
	for i in queue.size():
		var n: Node3D = queue[i].node
		n.visible = i < BELT_SLOTS
		if n.visible:
			var tx := BELT_FRONT_X + i * BELT_STEP
			n.position = n.position.move_toward(Vector3(tx, BELT_Y, BELT_Z), 5.0 * d)
	if held != null:
		held.node.visible = true
		held.node.position = held.node.position.move_toward(HOLD_POS, 8.0 * d)

## 홀드 집게: 벨트 맨 앞 블록을 챙기거나, 챙겨 둔 블록과 맞바꾼다.
func _hold() -> void:
	if held == null:
		if not queue.is_empty():
			held = queue.pop_front()
	elif queue.is_empty():
		queue.push_front(held)
		held = null
	else:
		var front = queue[0]
		queue[0] = held
		held = front

# ---------------------------------------------------------------- 수집 로봇

func _spawn_robot() -> void:
	robot = AnimatableBody3D.new()
	robot.sync_to_physics = false
	robot.position = ROBOT_HOME
	robot.set_meta("tag", "robot")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 0.9, 0.9)
	cs.shape = bs
	robot.add_child(cs)
	robot.add_child(_box(Vector3.ZERO, Vector3(0.8, 0.5, 0.8), Color(0.2, 0.8, 0.85), false))
	robot.add_child(_box(Vector3(0, 0.35, 0), Vector3(1.3, 0.08, 0.2), Color(0.9, 0.9, 0.95), false))
	robot.add_child(_box(Vector3(0, 0.35, 0), Vector3(0.2, 0.08, 1.3), Color(0.9, 0.9, 0.95), false))
	add_child(robot)

func _robot_fly(to: Vector3, d: float) -> bool:
	var speed: float = Player.SPEED * player.speed_mult * ROBOT_PCT[_lv("robot_speed")]
	var p := robot.position
	var flat := Vector2(to.x - p.x, to.z - p.z).length()
	# 멀리 있을 때는 언덕 위 높이로 날고, 가까워지면 내려간다.
	var aim := to if flat < 1.5 else Vector3(to.x, max(to.y, 7.0), to.z)
	robot.position = p.move_toward(aim, speed * d)
	return robot.position.distance_to(to) < 0.3

func _tick_robot(d: float) -> void:
	if robot == null:
		return
	if robot_cargo != null:
		if _robot_fly(INTAKE_POS + Vector3(0, 3.0, 0), d) and queue.size() < intake_cap:
			_enqueue(robot_cargo.kind, robot_cargo.color)
			inserted += 1
			robot_cargo = null
			robot_cargo_vis.queue_free()
		return
	if not robot_on:
		_robot_fly(ROBOT_HOME, d)
		return
	if not is_instance_valid(robot_target) or robot_target.flying \
			or robot_target.is_queued_for_deletion():
		robot_target = null
		var n := pieces_root.get_child_count()
		for i in 8:
			if n == 0:
				break
			var c := pieces_root.get_child(randi() % n) as PlainPiece
			if c != null and not c.flying and not c.is_queued_for_deletion():
				robot_target = c
				break
	if robot_target == null:
		_robot_fly(ROBOT_HOME, d)
		return
	if _robot_fly(robot_target.global_position + Vector3(0, 0.9, 0), d):
		robot_cargo = {"kind": robot_target.kind, "color": robot_target.color}
		robot_target.queue_free()
		robot_target = null
		plain_count -= 1
		robot_cargo_vis = Blocks.piece_visual(robot_cargo.kind, 0.25, robot_cargo.color)
		robot_cargo_vis.position.y = -1.0
		robot.add_child(robot_cargo_vis)

# ---------------------------------------------------------------- 조종석

func _sit() -> void:
	seated = true
	player.active = false
	seat_cam.current = true
	l_prompt.text = ""
	if is_instance_valid(hover):
		hover.set_glow(0.6 if hover.marked else 0.0)
	hover = null

func _stand() -> void:
	seated = false
	menu_open = false
	_refresh_menu()
	player.active = true
	player.cam.current = true

func _on_locked(info: Dictionary) -> void:
	spawn_cd = 0.35
	if info.lines == 0:
		return
	var m := "%.1f" % info.mult
	if m.ends_with(".0"):
		m = m.left(m.length() - 2)
	l_gain.text = "+%s   x%s" % [_fmt(info.gain), m]
	gain_t = 2.5
	# 스킬 포인트: k번째 포인트에 1.6 + 0.16 × (k − 1)줄, 맵 크기에 비례.
	sp_lines += info.lines
	while sp_earned < MAX_SP and sp_lines >= _sp_need():
		sp_lines -= _sp_need()
		sp_earned += 1
		sp += 1
	ground_mat.set_shader_parameter("radius", sqrt(_progress()) * 75.0)

func _sp_need() -> float:
	return (1.6 + 0.16 * sp_earned) * (total_blocks / 2000.0)

func _progress() -> float:
	return clamp(grid.cells_cleared / float(max(1, init_cells)), 0.0, 1.0)

func _on_overflowed(list: Array) -> void:
	cannon_queue.append_array(list)
	total += list.size()
	plain_count += list.size()
	_msg("넘침! 블록 %d개가 평원으로 돌아간다" % list.size())

func _on_returned(p: Dictionary) -> void:
	cannon_queue.append(p)
	total += 1
	plain_count += 1
	spawn_cd = 0.35

func _tick_cannon(d: float) -> void:
	if cannon_queue.is_empty():
		return
	cannon_t -= d
	if cannon_t > 0.0:
		return
	cannon_t = 0.12
	var p = cannon_queue.pop_front()
	var pc := _make_piece(p.kind, p.color, Blocks.flat_offsets(p.kind))
	var muzzle := Vector3(grid.w * GCELL / 2.0 + 2.6, GRID_Y + 4.2, GRID_Z + 3.6)
	pc.position = muzzle
	pieces_root.add_child(pc)
	var side := HILL_N * CELL
	var target := HILL_ORIGIN + Vector3(randf_range(7, side - 7), 1.5, randf_range(7, side - 7))
	var t := randf_range(2.0, 2.8)
	var v := (target - muzzle) / t
	v.y = (target.y - muzzle.y) / t + 0.5 * 9.8 * t
	pc.launch(v, Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)))

func _check_clear() -> void:
	if plain_count > 0 or not carried.is_empty() or robot_cargo != null \
			or not cannon_queue.is_empty():
		return
	cleared = true
	ground_mat.set_shader_parameter("radius", 200.0)
	clear_panel.text = "정리 완료!\n\n걸린 시간  %s\n점수  %s" % [_clock(elapsed), _fmt(grid.score)]
	clear_panel.visible = true

# ---------------------------------------------------------------- 스킬

func _menu_input() -> void:
	if Input.is_action_just_pressed("interact"):
		menu_open = false
	elif Input.is_action_just_pressed("fwd"):
		menu_sel = (menu_sel + SKILLS.size() - 1) % SKILLS.size()
	elif Input.is_action_just_pressed("back"):
		menu_sel = (menu_sel + 1) % SKILLS.size()
	elif Input.is_action_just_pressed("buy"):
		_buy(menu_sel)
	else:
		return
	_refresh_menu()

func _buy(i: int) -> void:
	var s: Dictionary = SKILLS[i]
	var l := _lv(s.id)
	if l >= s.costs.size():
		_msg("이미 최대 단계다")
		return
	if s.id == "robot_speed" and _lv("robot") == 0:
		_msg("수집 로봇이 먼저 필요하다")
		return
	var cost: int = s.costs[l]
	if sp < cost:
		_msg("스킬 포인트가 모자란다 (%d 필요)" % cost)
		return
	sp -= cost
	l += 1
	levels[s.id] = l
	match s.id:
		"speed":
			player.speed_mult = 1.0 + 0.2 * l
		"jump":
			player.jump_mult = sqrt(1.0 + 0.25 * l)
		"jet":
			player.jet_unlocked = true
		"intake":
			intake_cap = 5 + 5 * l
		"robot":
			_spawn_robot()
		"grid":
			grid.resize(5 + l, 5 + 2 * l)
			_build_frame()

func _refresh_menu() -> void:
	menu_bg.visible = menu_open
	if not menu_open:
		return
	var t := "[font_size=30]스킬  ·  남은 포인트 %d[/font_size]\n\n[table=4]" % sp
	for i in SKILLS.size():
		var s: Dictionary = SKILLS[i]
		var l := _lv(s.id)
		var n: int = s.costs.size()
		var pips := "●".repeat(l) + "○".repeat(n - l)
		var cost := "완료"
		var cost_col := "#8fd68f"
		if l < n:
			cost = "%dP" % s.costs[l]
			cost_col = "#ffffff" if sp >= s.costs[l] else "#e07070"
		var col := "#ffd84d" if i == menu_sel else "#d8d8e0"
		var mark := "▶ " if i == menu_sel else "    "
		t += "[cell][color=%s]%s%s   [/color][/cell]" % [col, mark, s.name]
		t += "[cell][color=%s]%s   [/color][/cell]" % [col, pips]
		t += "[cell][color=%s]%s   [/color][/cell]" % [cost_col, cost]
		t += "[cell][color=#a8a8b8]%s · %s[/color][/cell]" % [s.role, s.desc]
	t += "[/table]\n\n[color=#a8a8b8]W/S 고르기 · Enter 투자 · Tab 닫기 · 블록은 계속 떨어진다[/color]"
	menu_text.text = t

# ---------------------------------------------------------------- 격자 그리기

func _cell_pos(x: float, y: float) -> Vector3:
	return Vector3((x - grid.w / 2.0 + 0.5) * GCELL, GRID_Y + (y + 0.5) * GCELL, GRID_Z)

func _put(i: int, x: int, y: int, color: Color, glow: float) -> void:
	while pool.size() <= i:
		var mi := Blocks.cell_mesh(GCELL, Color.WHITE)
		grid_root.add_child(mi)
		pool.append(mi)
	var m: MeshInstance3D = pool[i]
	m.visible = true
	m.position = _cell_pos(x, y)
	m.set_instance_shader_parameter("tint", color)
	m.set_instance_shader_parameter("glow", glow)

func _fx(i: int, pos: Vector3, size: Vector3, mat: Material) -> void:
	while fx_pool.size() <= i:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grid_root.add_child(mi)
		fx_pool.append(mi)
	var m: MeshInstance3D = fx_pool[i]
	m.visible = true
	m.position = pos
	m.scale = size
	m.material_override = mat

func _draw_grid() -> void:
	var n := 0
	var f := 0
	for y in grid.h:
		for x in grid.w:
			var c = grid.cells[y * grid.w + x]
			if c != null:
				# 고정된 블록은 시간이 지나면서 서서히 테마 재질로 변한다.
				var age: float = clamp((elapsed - c.t - 5.0) / 25.0, 0.0, 1.0)
				_put(n, x, y, (c.c as Color).lerp(THEME_COLOR, age), 0.0)
				n += 1
	var a = grid.active
	claw.visible = a != null
	if a != null:
		var s := Shapes.size(a.cells)
		for c in a.cells:
			_put(n, a.x + c.x, a.y + c.y, a.color, 0.2)
			n += 1
		claw.position = _cell_pos(a.x + (s.x - 1) / 2.0, a.y + s.y - 0.5) + Vector3(0, 0.25, 0)
		var laser := _lv("laser")
		if laser > 0:
			var fall := 0
			while grid.fits(a.cells, a.x, a.y - fall - 1):
				fall += 1
			# Lv.1: 블록이 떨어질 열을 레이저로 표시한다.
			var lows := {}
			for c in a.cells:
				lows[c.x] = min(lows.get(c.x, 99), c.y)
			for cx in lows:
				var from_y: int = a.y + lows[cx]
				var to_y: int = from_y - fall if laser > 1 else 0
				if from_y > to_y:
					var mid := _cell_pos(a.x + cx, (from_y + to_y) / 2.0 - 0.5)
					_fx(f, mid + Vector3(0, 0, GCELL / 2.0 + 0.1),
						Vector3(0.14, (from_y - to_y) * GCELL, 0.14), beam_mat)
					f += 1
			# Lv.2: 레이저가 닿는 착지점이 빛난다.
			if laser > 1 and fall > 0:
				for c in a.cells:
					_fx(f, _cell_pos(a.x + c.x, a.y - fall + c.y), Vector3.ONE * GCELL * 1.02, ghost_mat)
					f += 1
	for i in range(n, pool.size()):
		pool[i].visible = false
	for i in range(f, fx_pool.size()):
		fx_pool[i].visible = false

# ---------------------------------------------------------------- HUD

func _lab(preset: int, l: float, t: float, r: float, b: float, size: int, align: int) -> Label:
	var lb := Label.new()
	lb.set_anchors_preset(preset)
	lb.offset_left = l
	lb.offset_top = t
	lb.offset_right = r
	lb.offset_bottom = b
	lb.horizontal_alignment = align
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_constant_override("outline_size", 6)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	layer.add_child(root)

	l_counter = _lab(Control.PRESET_TOP_RIGHT, -460, 16, -28, 80, 44, HORIZONTAL_ALIGNMENT_RIGHT)
	l_time = _lab(Control.PRESET_TOP_RIGHT, -460, 76, -28, 110, 22, HORIZONTAL_ALIGNMENT_RIGHT)
	l_score = _lab(Control.PRESET_TOP_LEFT, 28, 16, 460, 70, 36, HORIZONTAL_ALIGNMENT_LEFT)
	l_gain = _lab(Control.PRESET_TOP_LEFT, 28, 66, 460, 104, 26, HORIZONTAL_ALIGNMENT_LEFT)
	l_gain.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	l_sp = _lab(Control.PRESET_TOP_LEFT, 28, 108, 460, 138, 20, HORIZONTAL_ALIGNMENT_LEFT)
	l_msg = _lab(Control.PRESET_CENTER_TOP, -500, 120, 500, 170, 30, HORIZONTAL_ALIGNMENT_CENTER)
	l_prompt = _lab(Control.PRESET_CENTER, -400, 50, 400, 90, 24, HORIZONTAL_ALIGNMENT_CENTER)
	l_help = _lab(Control.PRESET_BOTTOM_LEFT, 28, -50, 1300, -18, 18, HORIZONTAL_ALIGNMENT_LEFT)
	l_status = _lab(Control.PRESET_BOTTOM_RIGHT, -620, -150, -28, -18, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	l_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	clear_panel = _lab(Control.PRESET_CENTER, -500, -160, 500, 160, 48, HORIZONTAL_ALIGNMENT_CENTER)
	clear_panel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_panel.visible = false
	for lb in [l_counter, l_time, l_score, l_gain, l_sp, l_msg, l_prompt, l_help, l_status, clear_panel]:
		root.add_child(lb)

	sp_bar = ProgressBar.new()
	sp_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sp_bar.offset_left = 28
	sp_bar.offset_top = 142
	sp_bar.offset_right = 268
	sp_bar.offset_bottom = 154
	sp_bar.show_percentage = false
	sp_bar.max_value = 1.0
	sp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sp_bar)

	cross = ColorRect.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -3
	cross.offset_top = -3
	cross.offset_right = 3
	cross.offset_bottom = 3
	cross.color = Color(1, 1, 1, 0.8)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)

	menu_bg = ColorRect.new()
	menu_bg.set_anchors_preset(Control.PRESET_CENTER)
	menu_bg.offset_left = -640
	menu_bg.offset_top = -330
	menu_bg.offset_right = 640
	menu_bg.offset_bottom = 330
	menu_bg.color = Color(0.05, 0.06, 0.09, 0.88)
	menu_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_bg.visible = false
	root.add_child(menu_bg)
	menu_text = RichTextLabel.new()
	menu_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_text.offset_left = 32
	menu_text.offset_top = 24
	menu_text.offset_right = -32
	menu_text.offset_bottom = -24
	menu_text.bbcode_enabled = true
	menu_text.scroll_active = false
	menu_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_text.add_theme_font_size_override("normal_font_size", 21)
	menu_bg.add_child(menu_text)

func _update_hud(d: float) -> void:
	l_counter.text = "%s / %s" % [_fmt(inserted), _fmt(total)]
	l_time.text = _clock(elapsed)
	l_score.text = "점수 %s" % _fmt(grid.score)
	l_sp.text = "스킬 포인트 %d" % sp
	sp_bar.value = sp_lines / _sp_need() if sp_earned < MAX_SP else 1.0
	gain_t -= d
	l_gain.visible = gain_t > 0.0
	msg_t -= d
	l_msg.visible = msg_t > 0.0
	cross.visible = not seated

	var st: Array = []
	if not seated and not feeding and not queue.is_empty():
		st.append("조종석에 앉으면 블록이 나온다")
	if robot != null:
		st.append("수집 로봇 켜짐" if robot_on else "수집 로봇 꺼짐")
	if player.jet_unlocked:
		if player.jet_t > 0.0:
			st.append("제트팩 %.1f초" % player.jet_t)
		elif player.jet_cd > 0.0:
			st.append("제트팩 대기 %d초" % ceil(player.jet_cd))
		else:
			st.append("[F] 제트팩")
	var cap: int = CARRY_CAPS[_lv("carry")]
	if cap > 1:
		st.append("든 블록 %d / %d" % [carried.size(), cap])
	l_status.text = "\n".join(st)

	if seated:
		l_help.text = "A/D 좌우 · S 내리기 · W 회전 · Z 반대로 회전 · C 홀드 집게 · R 반송구 · Tab 스킬 · E 일어나기"
	else:
		var h := "WASD 이동 · Space 점프 · E 줍기/넣기/앉기 · Q 내려놓기"
		if cap > 1:
			h += " · X 순서 바꾸기"
		if _lv("tidy") > 0:
			h += " · G 정리 내려놓기"
		l_help.text = h + " · Esc 마우스 풀기"

func _msg(text: String) -> void:
	l_msg.text = text
	msg_t = 2.5

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out

func _clock(t: float) -> String:
	var sec := int(t)
	return "%d:%02d:%02d" % [sec / 3600, (sec / 60) % 60, sec % 60]
