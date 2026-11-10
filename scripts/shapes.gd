class_name Shapes
## 블록 모양 정의. 좌표는 (x, y), y가 위쪽.

enum { I, O, T, L, J, S, Z, DOT, DUO, CORNER }
const COUNT := 10

const CELLS := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
]

## 스핀 배율 최대치 = 블록의 긴 변 길이. 0이면 스핀 없음.
const LONG := [4, 2, 3, 3, 3, 3, 3, 0, 2, 2]

static func size(cells: Array) -> Vector2i:
	var s := Vector2i.ZERO
	for c in cells:
		s.x = max(s.x, c.x + 1)
		s.y = max(s.y, c.y + 1)
	return s

## dir > 0 시계 방향, dir < 0 반시계 방향. 결과는 (0,0) 기준으로 정규화한다.
static func rotated(cells: Array, dir: int) -> Array:
	var out := []
	var mn := Vector2i(99, 99)
	for c in cells:
		var r := Vector2i(c.y, -c.x) if dir > 0 else Vector2i(-c.y, c.x)
		out.append(r)
		mn.x = min(mn.x, r.x)
		mn.y = min(mn.y, r.y)
	for i in out.size():
		out[i] -= mn
	return out

static func random_color() -> Color:
	return Color.from_hsv(randf(), randf_range(0.55, 0.85), randf_range(0.8, 1.0))
