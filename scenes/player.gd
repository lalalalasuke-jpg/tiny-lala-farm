extends Node2D

# くま紳士ららすけ（プレイヤー）。walk_to() で目的地へ歩き、着いたら arrived を出す。
# PC では矢印キーでも歩ける（そのときは目的地は取り消して canceled を出す）。

signal arrived
signal canceled

const SPEED := 420.0

var bounds := Rect2(0, 0, 720, 1280)
var target := Vector2.ZERO
var walking := false
var _t := 0.0  # 歩きの揺れ用
var _clock := 0.0  # まばたき用
var face := 1.0  # 向き（1 = 右、-1 = 左）


func walk_to(pos: Vector2) -> void:
	target = pos.clamp(bounds.position, bounds.end)
	walking = true


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var moving := false
	if dir != Vector2.ZERO:
		if walking:
			walking = false
			canceled.emit()
		position = (position + dir * SPEED * delta).clamp(bounds.position, bounds.end)
		moving = true
	elif walking:
		position = position.move_toward(target, SPEED * delta)
		moving = true
		if position == target:
			walking = false
			arrived.emit()
	var dx := dir.x if dir != Vector2.ZERO else (target.x - position.x if walking else 0.0)
	if absf(dx) > 2:
		face = signf(dx)
	_t = _t + delta * 14 if moving else 0.0
	_clock += delta
	queue_redraw()


func _draw() -> void:
	_bear(0.52)


# くま紳士ららすけ（グレーのくま、カンカン帽、ベスト、モノクル）。s は大きさ。
# モノクルは、くま自身の左目（正面から見て向かって右の目）。左右の向きを変えても目は入れかえない
func _bear(s: float) -> void:
	var line := Color(0.33, 0.22, 0.14)
	var fur := Color(0.7, 0.69, 0.72)
	var fur_dark := Color(0.55, 0.54, 0.58)
	var bob := Vector2(0, -abs(sin(_t)) * 5)
	draw_set_transform(Vector2(0, 92 * s), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 46 * s, Color(0, 0, 0, 0.18))  # 影
	draw_set_transform(Vector2.ZERO)
	# 足（歩くと交互に動く）
	var step := sin(_t) * 6
	for side in [-1, 1]:
		_box(Rect2(Vector2(side * 18 - 11, 66 + step * side) * s, Vector2(22, 26) * s), fur, line, 9)
	# からだ（シャツ＋ベスト）
	_box(Rect2(Vector2(-34, 4) * s + bob, Vector2(68, 70) * s), Color(0.86, 0.85, 0.82), line, 22)
	_box(Rect2(Vector2(-34, 6) * s + bob, Vector2(68, 66) * s), Color(0.32, 0.32, 0.35), line, 22)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 6) * s + bob, Vector2(10, 6) * s + bob, Vector2(0, 30) * s + bob]), Color(0.92, 0.91, 0.88))
	for k in 2:
		draw_circle(Vector2(0, 40 + k * 14) * s + bob, 3 * s, Color(0.85, 0.75, 0.4))
	# うで（歩くと前後にふる）
	for side in [-1, 1]:
		var arm := Vector2(side * 38, 30 + sin(_t) * 4 * side) * s + bob
		draw_circle(arm, 14 * s, line)
		draw_circle(arm, 12 * s, fur)
	# 頭
	var h := Vector2(0, -30) * s + bob
	for side in [-1, 1]:  # 耳
		draw_circle(h + Vector2(side * 30, -30) * s, 17 * s, line)
		draw_circle(h + Vector2(side * 30, -30) * s, 15 * s, fur)
		draw_circle(h + Vector2(side * 30, -30) * s, 8 * s, fur_dark)
	draw_circle(h, 45 * s, line)
	draw_circle(h, 42 * s, fur)
	var look := Vector2(face * 5, 0) * s
	draw_set_transform(h + look + Vector2(0, 14) * s, 0, Vector2(1, 0.75))
	draw_circle(Vector2.ZERO, 18 * s, Color(0.93, 0.92, 0.9))  # 口のまわり
	draw_set_transform(Vector2.ZERO)
	draw_circle(h + look + Vector2(0, 6) * s, 6 * s, line)  # 鼻
	draw_arc(h + look + Vector2(0, 14) * s, 6 * s, 0.3, PI - 0.3, 8, line, 2)  # にっこり
	var eyes := [h + look + Vector2(-16, -8) * s, h + look + Vector2(16, -8) * s]
	for e in eyes:
		if fmod(_clock, 3.2) < 0.13:  # まばたき
			draw_line(e + Vector2(-4, 0) * s, e + Vector2(4, 0) * s, line, 2)
		else:
			draw_circle(e, 4.5 * s, line)
			draw_circle(e + Vector2(1.5, -1.5) * s, 1.5 * s, Color(1, 1, 1))
	var mono: Vector2 = eyes[1]  # モノクル（金のふち）と、お腹へ垂れる鎖
	draw_arc(mono, 11 * s, 0, TAU, 20, line, 4)
	draw_arc(mono, 11 * s, 0, TAU, 20, Color(0.87, 0.7, 0.34), 2.5)
	draw_polyline(PackedVector2Array([mono + Vector2(10, 6) * s, mono + Vector2(14, 30) * s, Vector2(18, 22) * s + bob, Vector2(10, 40) * s + bob]), Color(0.87, 0.7, 0.34), 1.5)
	draw_circle(h + look + Vector2(-26, 8) * s, 6 * s, Color(1, 0.6, 0.62, 0.5))  # ほっぺ
	draw_circle(h + look + Vector2(26, 8) * s, 6 * s, Color(1, 0.6, 0.62, 0.5))
	# カンカン帽（ベージュに黒いリボン）
	_box(Rect2(h + Vector2(-44, -42) * s, Vector2(88, 12) * s), Color(0.9, 0.8, 0.6), line, 6)
	_box(Rect2(h + Vector2(-26, -66) * s, Vector2(52, 28) * s), Color(0.9, 0.8, 0.6), line, 6)
	draw_rect(Rect2(h + Vector2(-25, -48) * s, Vector2(50, 8) * s), Color(0.15, 0.13, 0.13))


func _box(r: Rect2, fill: Color, border: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius * 0.6))
	sb.border_color = border
	sb.set_border_width_all(2)
	draw_style_box(sb, r)
