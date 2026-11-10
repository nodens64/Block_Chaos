extends SceneTree
## 격자 규칙 검사. 실행: godot --headless --path . --script tests/test_grid.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func drop(g: GridLogic, kind: int, x: int, rot := 0) -> void:
	g.spawn(kind, Color.WHITE)
	for i in rot:
		g.rotate(1)
	while g.active.x > x and g.move(-1):
		pass
	while g.active.x < x and g.move(1):
		pass
	g.hard_drop()

## 일자 블록을 세로로 세워 x열에 떨어뜨린다.
func stand(g: GridLogic, x: int) -> void:
	g.spawn(Shapes.I, Color.WHITE)
	g.active.cells = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
	g.active.x = x
	g.active.y = 1
	g.hard_drop()

func _init() -> void:
	var last := {}
	var g := GridLogic.new(5, 5)
	g.locked.connect(func(i): last.assign(i))

	# 한 줄 제거: 5칸 격자에서 줄당 50점, x1
	drop(g, Shapes.I, 0)
	drop(g, Shapes.DOT, 4)
	check(last.lines == 1 and last.gain == 50, "1줄 제거 = 50점 (%s)" % last.gain)
	check(g.score == 50 and g.pieces.is_empty(), "줄이 지워지면 격자가 빈다")

	# 연속 제거: 두 번째는 x1.2
	drop(g, Shapes.I, 0)
	drop(g, Shapes.I, 0)
	drop(g, Shapes.DOT, 4)
	drop(g, Shapes.DOT, 4)
	check(last.gain == 60 and is_equal_approx(last.mult, 1.2), "연속 2번째 = x1.2, 60점 (%s)" % last.gain)

	# 줄을 못 지우면 연속이 끊긴다
	drop(g, Shapes.DOT, 0)
	check(last.lines == 0 and g.combo == 0, "제거 없이 고정하면 연속 초기화")

	# 4줄 제거: x2
	g = GridLogic.new(5, 5)
	g.locked.connect(func(i): last.assign(i))
	for x in 4:
		stand(g, x)
	check(g.pieces.size() == 4 and last.lines == 0, "세로 일자 4개를 세운다")
	stand(g, 4)
	check(last.lines == 4 and last.gain == 50 * 4 * 2, "4줄 제거 = x2, 400점 (%s)" % last.gain)

	# 가로가 넓을수록 줄당 점수가 높다
	check(GridLogic.new(8, 11).line_score() == 128 and GridLogic.new(10, 15).line_score() == 200,
		"줄당 점수 8칸 128, 10칸 200")

	# 스핀: 회전으로 끼워 넣어 움직일 수 없는 자리에서 고정
	g = GridLogic.new(5, 5)
	g.locked.connect(func(i): last.assign(i))
	for x in [0, 1, 3, 4]:
		g.cells[x] = {"c": Color.WHITE, "t": 0.0, "pid": 99}
	for x in [0, 4]:
		g.cells[5 + x] = {"c": Color.WHITE, "t": 0.0, "pid": 99}
	g.cells[10] = {"c": Color.WHITE, "t": 0.0, "pid": 99}
	g.cells[11] = {"c": Color.WHITE, "t": 0.0, "pid": 99}
	g.cells[14] = {"c": Color.WHITE, "t": 0.0, "pid": 99}
	g.pieces[99] = {"kind": Shapes.DOT, "color": Color.WHITE, "left": 99}
	g.spawn(Shapes.T, Color.WHITE)
	g.active.cells = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 0)]
	g.active.x = 1
	g.active.y = 0
	g.last_rot = true
	g.lock()
	check(last.spin and last.lines == 2 and last.gain == 50 * 2 * 2, "T 스핀 2줄 = x2, 200점 (%s)" % last.gain)

	# 1×1은 스핀이 없다
	check(not GridLogic.new().rotate(1), "블록이 없으면 회전하지 않는다")
	g = GridLogic.new(5, 5)
	g.spawn(Shapes.DOT, Color.WHITE)
	check(not g.rotate(1), "1×1은 회전(스핀)이 없다")

	# 반송구
	var back := []
	g.returned.connect(func(p): back.append(p))
	g.send_to_chute()
	check(back.size() == 1 and g.active == null, "반송구로 보내면 격자에서 빠진다")

	# 넘침: 격자의 블록과 들어오던 블록이 모두 평원으로 간다. 점수는 그대로.
	g = GridLogic.new(5, 5)
	var spilled := []
	g.overflowed.connect(func(l): spilled.assign(l))
	g.score = 777
	for i in 5:
		g.spawn(Shapes.DUO, Color.WHITE)
		if g.active != null:
			g.hard_drop()
	check(spilled.is_empty(), "5칸 높이에 1×2 다섯 개는 넘치지 않는다")
	var ok := g.spawn(Shapes.DUO, Color.WHITE)
	check(not ok and spilled.size() == 6, "여섯 번째에서 넘쳐 6개가 쏟아진다 (%d)" % spilled.size())
	check(g.pieces.is_empty() and g.score == 777, "넘친 뒤 빈 격자, 점수 유지")

	# 격자 확장
	g = GridLogic.new(5, 5)
	drop(g, Shapes.DOT, 0)
	g.resize(6, 7)
	check(g.w == 6 and g.h == 7 and g.cells[0] != null and g.cells.size() == 42, "격자 확장 5×5 → 6×7")

	print("\n실패 %d건" % fails)
	quit(1 if fails > 0 else 0)
