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
	_t = _t + delta * 14 if moving else 0.0
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, -abs(sin(_t)) * 5)
	draw_circle(Vector2(0, 30), 24, Color(0, 0, 0, 0.18))  # 影
	draw_rect(Rect2(Vector2(-18, -6) + bob, Vector2(36, 36)), Color(0.3, 0.45, 0.85))  # オーバーオール
	draw_circle(Vector2(0, -22) + bob, 20, Color(1.0, 0.85, 0.72))  # 顔
	draw_circle(Vector2(-7, -22) + bob, 2.5, Color(0.2, 0.15, 0.1))
	draw_circle(Vector2(7, -22) + bob, 2.5, Color(0.2, 0.15, 0.1))
	draw_circle(Vector2(-12, -14) + bob, 4, Color(1, 0.6, 0.6, 0.6))  # ほっぺ
	draw_circle(Vector2(12, -14) + bob, 4, Color(1, 0.6, 0.6, 0.6))
	# 麦わら帽子
	draw_rect(Rect2(Vector2(-30, -40) + bob, Vector2(60, 8)), Color(0.95, 0.8, 0.35))
	draw_rect(Rect2(Vector2(-16, -54) + bob, Vector2(32, 16)), Color(0.95, 0.8, 0.35))
	draw_rect(Rect2(Vector2(-16, -44) + bob, Vector2(32, 4)), Color(0.85, 0.3, 0.3))
