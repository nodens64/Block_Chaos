class_name GridLogic
extends RefCounted
## 거대 격자의 규칙만 담는다. 화면 표시는 main.gd가 맡는다.

signal locked(info)        # {lines, gain, mult, combo, spin}
signal overflowed(pieces)  # [{kind, color}, ...]
signal returned(piece)     # {kind, color}

var w := 5
var h := 5
var cells: Array = []      # [y * w + x] = null 또는 {c, t, pid}
var pieces := {}           # pid -> {kind, color, left}
var next_pid := 1
var active = null          # {kind, color, cells, x, y}
var last_rot := false
var combo := 0
var score := 0
var lines_total := 0
var cells_cleared := 0
var clock := 0.0

func _init(width := 5, height := 5) -> void:
	w = width
	h = height
	cells.resize(w * h)

func line_score() -> int:
	return w * w * 2

func fits(cs: Array, x: int, y: int) -> bool:
	for c in cs:
		var px: int = x + c.x
		var py: int = y + c.y
		if px < 0 or px >= w or py < 0 or py >= h:
			return false
		if cells[py * w + px] != null:
			return false
	return true

func spawn(kind: int, color: Color) -> bool:
	var cs: Array = Shapes.CELLS[kind].duplicate()
	var s := Shapes.size(cs)
	var x := (w - s.x) / 2
	var y := h - s.y
	if s.x > w or s.y > h or not fits(cs, x, y):
		_overflow({"kind": kind, "color": color})
		return false
	active = {"kind": kind, "color": color, "cells": cs, "x": x, "y": y}
	last_rot = false
	return true

func move(dx: int) -> bool:
	if active == null or not fits(active.cells, active.x + dx, active.y):
		return false
	active.x += dx
	last_rot = false
	return true

func rotate(dir: int) -> bool:
	if active == null or active.kind == Shapes.O or active.kind == Shapes.DOT:
		return false
	var cs := Shapes.rotated(active.cells, dir)
	var s0 := Shapes.size(active.cells)
	var s1 := Shapes.size(cs)
	var bx: int = active.x + (s0.x - s1.x) / 2
	var by: int = active.y + (s0.y - s1.y) / 2
	for k in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1),
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2)]:
		if fits(cs, bx + k.x, by + k.y):
			active.cells = cs
			active.x = bx + k.x
			active.y = by + k.y
			last_rot = true
			return true
	return false

## 한 칸 내린다. 더 못 내려가면 고정한다.
func step_down() -> void:
	if active == null:
		return
	if fits(active.cells, active.x, active.y - 1):
		active.y -= 1
		last_rot = false
	else:
		lock()

func hard_drop() -> void:
	if active == null:
		return
	while fits(active.cells, active.x, active.y - 1):
		active.y -= 1
		last_rot = false
	lock()

## 잡고 있는 블록을 반송구로 보낸다.
func send_to_chute() -> bool:
	if active == null:
		return false
	var p := {"kind": active.kind, "color": active.color}
	active = null
	returned.emit(p)
	return true

func lock() -> void:
	var a = active
	active = null
	var spin: bool = last_rot and Shapes.LONG[a.kind] > 0 \
		and not fits(a.cells, a.x - 1, a.y) and not fits(a.cells, a.x + 1, a.y) \
		and not fits(a.cells, a.x, a.y + 1)
	var pid := next_pid
	next_pid += 1
	pieces[pid] = {"kind": a.kind, "color": a.color, "left": a.cells.size()}
	for c in a.cells:
		cells[(a.y + c.y) * w + a.x + c.x] = {"c": a.color, "t": clock, "pid": pid}

	var kept: Array = []
	var lines := 0
	for y in h:
		var full := true
		for x in w:
			if cells[y * w + x] == null:
				full = false
				break
		if full:
			lines += 1
			for x in w:
				var id: int = cells[y * w + x].pid
				pieces[id].left -= 1
				if pieces[id].left <= 0:
					pieces.erase(id)
		else:
			kept.append_array(cells.slice(y * w, y * w + w))
	if lines > 0:
		kept.resize(w * h)
		cells = kept

	var info := {"lines": lines, "gain": 0, "mult": 0.0, "combo": 0, "spin": spin}
	if lines > 0:
		combo += 1
		var base: float
		if spin:
			base = float(min(lines, Shapes.LONG[a.kind]))
		else:
			base = 2.0 if lines >= 4 else 1.0
		var mult := base + 0.2 * (combo - 1)
		var gain := int(round(line_score() * lines * mult))
		score += gain
		lines_total += lines
		cells_cleared += lines * w
		info.gain = gain
		info.mult = mult
		info.combo = combo
	else:
		combo = 0
	locked.emit(info)

func _overflow(incoming: Dictionary) -> void:
	var out: Array = [incoming]
	for p in pieces.values():
		out.append({"kind": p.kind, "color": p.color})
	pieces.clear()
	cells.fill(null)
	active = null
	combo = 0
	overflowed.emit(out)

## 격자 확장. 기존 블록은 왼쪽 아래에 그대로 둔다.
func resize(nw: int, nh: int) -> void:
	var n: Array = []
	n.resize(nw * nh)
	for y in min(h, nh):
		for x in min(w, nw):
			n[y * nw + x] = cells[y * w + x]
	cells = n
	w = nw
	h = nh
