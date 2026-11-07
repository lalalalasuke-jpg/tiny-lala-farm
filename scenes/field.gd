extends Node2D

# 畑 3×3 と出荷箱の見た目。状態（plots）は main.gd が持っていて、ここは描くだけ。

const COLS := 3
const ROWS := 3
const PLOT := 140.0
const GAP := 10.0
const ORIGIN := Vector2(140, 330)  # 左上の畑の左上の角
const WALK_AREA := Rect2(30, 130, 660, 860)  # キャラが歩ける範囲
const BOX_RECT := Rect2(540, 830, 120, 90)
const BOX := 99  # main.gd の BOX と同じ（予約の行き先が出荷箱）

const FONT := preload("res://fonts/NotoSansJP-Subset.ttf")

var plots: Array = []  # main.gd から渡される（Dictionary の配列）
var crops: Dictionary = {}
var shipped_count := 0
var queued: Array = []  # タップの予約の行き先（畑の番号か BOX）を順番に


func plot_rect(i: int) -> Rect2:
	var c := i % COLS
	var r := i / COLS
	return Rect2(ORIGIN + Vector2(c, r) * (PLOT + GAP), Vector2(PLOT, PLOT))


# 収穫までに必要な日数（肥料をあげると1日早い）
func days_needed(p: Dictionary) -> int:
	var d: int = crops[p.crop].days
	return max(1, d - 1) if p.fert else d


func plot_center(i: int) -> Vector2:
	return plot_rect(i).get_center()


# pos にある畑の番号。畑の外なら -1
func plot_at(pos: Vector2) -> int:
	for i in COLS * ROWS:
		if plot_rect(i).grow(GAP / 2).has_point(pos):
			return i
	return -1


func box_stand_point() -> Vector2:
	return BOX_RECT.get_center() + Vector2(-100, 0)


func near_box(pos: Vector2) -> bool:
	return BOX_RECT.grow(70).has_point(pos)


func _draw() -> void:
	# 草地
	draw_rect(WALK_AREA, Color(0.45, 0.68, 0.36))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 80:
		var p := Vector2(rng.randf_range(40, 680), rng.randf_range(140, 980))
		draw_line(p, p + Vector2(4, -10), Color(0.36, 0.58, 0.3), 3)
	for i in plots.size():
		_draw_plot(i)
	_draw_box()
	_draw_queue()


# 予約の順番の数字。同じ場所に2つ以上あれば「1・3」のように並べる
func _draw_queue() -> void:
	var orders := {}
	for n in queued.size():
		var at: int = queued[n]
		if not orders.has(at):
			orders[at] = []
		orders[at].append(str(n + 1))
	for at in orders:
		var text := "・".join(orders[at])
		var top := BOX_RECT.position + Vector2(BOX_RECT.size.x / 2, 0) if at == BOX else plot_rect(at).position + Vector2(PLOT / 2, 0)
		var w := 16.0 + 14.0 * text.length()
		var r := Rect2(top + Vector2(-w / 2, 6), Vector2(w, 32))
		draw_rect(r, Color(1, 1, 1, 0.92))
		draw_rect(r, Color(0.3, 0.45, 0.85), false, 3)
		draw_string(FONT, r.position + Vector2(0, 24), text, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(0.2, 0.3, 0.6))


func _draw_plot(i: int) -> void:
	var rect := plot_rect(i)
	var p: Dictionary = plots[i]
	if not p.tilled:
		draw_rect(rect, Color(0.4, 0.6, 0.32))
		draw_rect(rect, Color(0.33, 0.5, 0.27), false, 4)
		return
	var soil := Color(0.45, 0.3, 0.18) if p.watered else Color(0.66, 0.48, 0.3)
	draw_rect(rect, soil)
	# うね（畝）の線
	for k in 3:
		var y := rect.position.y + 30 + k * 40
		draw_line(Vector2(rect.position.x + 12, y), Vector2(rect.end.x - 12, y), soil.darkened(0.2), 4)
	if p.crop == "":
		return
	var crop: Dictionary = crops[p.crop]
	var c := rect.get_center()
	var need := days_needed(p)
	if p.dead:
		# しおれた茎
		var brown := Color(0.42, 0.3, 0.16)
		draw_line(c + Vector2(0, 24), c + Vector2(4, -6), brown, 5)
		draw_line(c + Vector2(4, -6), c + Vector2(-18, 8), brown, 4)
		draw_line(c + Vector2(4, -6), c + Vector2(22, 12), brown, 4)
		draw_string(FONT, rect.position + Vector2(0, PLOT - 10), "枯れちゃった", HORIZONTAL_ALIGNMENT_CENTER, PLOT, 20, Color(1, 1, 1, 0.9))
		return
	if p.growth >= need:
		_draw_ripe(p.crop, crop.color, c)
	else:
		# 芽: 育つほど大きくなる
		var t: float = 0.35 + 0.65 * float(p.growth) / need
		var leaf := Color(0.3, 0.75, 0.3)
		draw_line(c + Vector2(0, 20), c + Vector2(0, 20 - 30 * t), leaf.darkened(0.2), 4)
		draw_circle(c + Vector2(-12 * t, 20 - 30 * t), 12 * t, leaf)
		draw_circle(c + Vector2(12 * t, 20 - 30 * t), 12 * t, leaf)
		# のこり日数
		var left := "あと%d日" % (need - p.growth)
		draw_string(FONT, rect.position + Vector2(0, PLOT - 10), left, HORIZONTAL_ALIGNMENT_CENTER, PLOT, 22, Color(1, 1, 1, 0.9))
	if not p.missed:
		# お世話かんぺき（一度も水やりを忘れてない）のハート。収穫の当たりが出やすい
		var h := rect.position + Vector2(PLOT - 24, PLOT - 52)
		var pink := Color(1, 0.45, 0.6)
		draw_circle(h + Vector2(-5, 0), 6, pink)
		draw_circle(h + Vector2(5, 0), 6, pink)
		draw_colored_polygon(PackedVector2Array([h + Vector2(-10.5, 2), h + Vector2(10.5, 2), h + Vector2(0, 13)]), pink)
	if p.fert:
		# 肥料のしるし
		var at := rect.position + Vector2(22, 24)
		draw_circle(at, 15, Color(0.95, 0.75, 0.3))
		draw_string(FONT, at + Vector2(-15, 7), "肥", HORIZONTAL_ALIGNMENT_CENTER, 30, 20, Color(0.45, 0.28, 0.1))
	if p.watered:
		_draw_drop(rect.position + Vector2(PLOT - 22, 24))


func _draw_ripe(id: String, color: Color, c: Vector2) -> void:
	var leaf := Color(0.25, 0.65, 0.25)
	match id:
		"turnip":
			draw_circle(c + Vector2(-14, -34), 14, leaf)
			draw_circle(c + Vector2(14, -34), 14, leaf)
			draw_circle(c + Vector2(0, 0), 34, color)
			draw_circle(c + Vector2(0, -20), 20, Color(0.7, 0.35, 0.75))
		"tomato":
			draw_line(c + Vector2(0, 40), c + Vector2(0, -45), leaf.darkened(0.2), 5)
			for o in [Vector2(-22, -18), Vector2(20, -4), Vector2(-14, 24)]:
				draw_circle(c + o, 20, color)
				draw_circle(c + o + Vector2(-6, -6), 5, Color(1, 1, 1, 0.5))
		"strawberry":
			draw_circle(c + Vector2(0, -30), 16, leaf)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -16), c + Vector2(34, -16), c + Vector2(0, 40)]), color)
			draw_circle(c + Vector2(-17, -12), 18, color)
			draw_circle(c + Vector2(17, -12), 18, color)
			for o in [Vector2(-12, -6), Vector2(10, -2), Vector2(0, 14), Vector2(-4, -16), Vector2(16, -16)]:
				draw_circle(c + o, 2.5, Color(1, 0.9, 0.4))
	# 収穫できる合図のキラキラ
	draw_string(FONT, c + Vector2(30, -40), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.95, 0.4))


func _draw_drop(at: Vector2) -> void:
	var blue := Color(0.35, 0.65, 1.0)
	draw_circle(at + Vector2(0, 6), 8, blue)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 4), at + Vector2(7, 4), at + Vector2(0, -10)]), blue)


func _draw_box() -> void:
	var r := BOX_RECT
	draw_rect(r, Color(0.6, 0.4, 0.22))
	draw_rect(r, Color(0.4, 0.25, 0.12), false, 5)
	draw_line(r.position + Vector2(0, 30), Vector2(r.end.x, r.position.y + 30), Color(0.4, 0.25, 0.12), 4)
	draw_string(FONT, r.position + Vector2(0, 72), "出荷箱", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color(1, 0.97, 0.9))
	if shipped_count > 0:
		draw_circle(r.position + Vector2(r.size.x, 0), 20, Color(0.9, 0.3, 0.3))
		draw_string(FONT, r.position + Vector2(r.size.x - 20, 9), str(shipped_count), HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color.WHITE)
