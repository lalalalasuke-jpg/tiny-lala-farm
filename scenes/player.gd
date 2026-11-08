extends Node2D

# ららすけ（プレイヤー）。walk_to() で目的地へ歩き、着いたら arrived を出す。
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
	var bob := Vector2(0, -abs(sin(_t)) * 5)
	var line := Color(0.3, 0.2, 0.12, 0.7)  # ふちどり
	draw_set_transform(Vector2(0, 32), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 26, Color(0, 0, 0, 0.18))  # 影
	draw_set_transform(Vector2.ZERO)
	# 足（歩くと交互に動く）
	var step := sin(_t) * 4
	for side in [-1, 1]:
		var foot := Vector2(side * 9, 28 + step * side)
		draw_line(Vector2(side * 9, 22) + bob, foot, Color(0.35, 0.25, 0.2), 7)
	# オーバーオール
	var body := Rect2(Vector2(-19, -7) + bob, Vector2(38, 34))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.48, 0.86)
	sb.set_corner_radius_all(10)
	sb.border_color = line
	sb.set_border_width_all(3)
	draw_style_box(sb, body)
	draw_circle(Vector2(-9, 2) + bob, 3, Color(1, 0.85, 0.4))  # ボタン
	draw_circle(Vector2(9, 2) + bob, 3, Color(1, 0.85, 0.4))
	# 顔
	var head := Vector2(0, -22) + bob
	draw_circle(head, 22, line)
	draw_circle(head, 20, Color(1.0, 0.86, 0.74))
	var look := Vector2(3 * face, 0)
	if fmod(_clock, 3.2) < 0.13:  # まばたき
		for x in [-7, 7]:
			draw_line(head + look + Vector2(x - 3, 1), head + look + Vector2(x + 3, 1), Color(0.2, 0.15, 0.1), 2)
	else:
		for x in [-7, 7]:
			draw_circle(head + look + Vector2(x, 0), 2.8, Color(0.2, 0.15, 0.1))
			draw_circle(head + look + Vector2(x + 1, -1), 1, Color(1, 1, 1))
	draw_arc(head + look + Vector2(0, 7), 4, 0.3, PI - 0.3, 8, Color(0.55, 0.3, 0.25), 2)  # にっこり
	draw_circle(head + Vector2(-12, 8), 4, Color(1, 0.6, 0.6, 0.6))  # ほっぺ
	draw_circle(head + Vector2(12, 8), 4, Color(1, 0.6, 0.6, 0.6))
	# 麦わら帽子
	var straw := Color(0.97, 0.82, 0.38)
	var brim := Rect2(Vector2(-31, -42) + bob, Vector2(62, 9))
	var crown := Rect2(Vector2(-16, -57) + bob, Vector2(32, 18))
	for r in [brim, crown]:
		var hs := StyleBoxFlat.new()
		hs.bg_color = straw
		hs.set_corner_radius_all(5)
		hs.border_color = line
		hs.set_border_width_all(3)
		draw_style_box(hs, r)
	draw_rect(Rect2(Vector2(-15, -45) + bob, Vector2(30, 4)), Color(0.85, 0.3, 0.3))  # リボン
