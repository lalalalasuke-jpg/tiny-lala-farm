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
# 一瞬だけ出る演出（土ぼこり・水しぶき・収穫でぴょこっと・文字）。t は 0→1 で進んで消える
var effects: Array = []

const FX_TIME := {"dust": 0.35, "splash": 0.45, "pop": 0.7, "text": 1.1}


# kind: dust / splash / pop（crop に作物id）/ text（text に文字）
func add_effect(kind: String, pos: Vector2, extra := {}) -> void:
	var e := {"kind": kind, "pos": pos, "t": 0.0}
	e.merge(extra)
	effects.append(e)
	queue_redraw()


func _process(delta: float) -> void:
	if effects.is_empty():
		return
	for e in effects:
		e.t += delta / FX_TIME[e.kind]
	effects = effects.filter(func(e): return e.t < 1.0)
	queue_redraw()


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
	_draw_ground()
	for i in plots.size():
		_draw_plot(i)
	_draw_box()
	_draw_queue()
	for e in effects:
		_draw_effect(e)


# 草地: うすい模様・草のふさ・小さな花・奥の柵。乱数の種を固定して毎回同じ配置にする
func _draw_ground() -> void:
	draw_rect(WALK_AREA, Color(0.47, 0.7, 0.38))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 14:  # 明るいところ
		var at := Vector2(rng.randf_range(60, 660), rng.randf_range(220, 960))
		_ellipse(at, rng.randf_range(40, 90), 0.45, Color(0.53, 0.75, 0.42, 0.6))
	var farm := Rect2(ORIGIN, Vector2(COLS, ROWS) * (PLOT + GAP)).grow(16)
	for k in 70:  # 草のふさ
		var at := Vector2(rng.randf_range(45, 675), rng.randf_range(225, 975))
		if farm.has_point(at):
			continue
		var g := Color(0.36, 0.58, 0.3)
		draw_line(at, at + Vector2(-5, -10), g, 3)
		draw_line(at, at + Vector2(1, -13), g, 3)
		draw_line(at, at + Vector2(6, -9), g, 3)
	var petals := [Color(1, 1, 1), Color(1, 0.85, 0.35), Color(1, 0.65, 0.75)]
	for k in 22:  # 小さな花
		var at := Vector2(rng.randf_range(50, 670), rng.randf_range(230, 970))
		if farm.has_point(at) or BOX_RECT.grow(30).has_point(at):
			continue
		var col: Color = petals[k % petals.size()]
		for a in 5:
			draw_circle(at + Vector2(6, 0).rotated(a * TAU / 5), 4.5, col)
		draw_circle(at, 3.5, Color(1, 0.75, 0.2) if col != petals[1] else Color(0.9, 0.5, 0.15))
	# 奥の木の柵
	var wood := Color(0.82, 0.62, 0.4)
	var dark := wood.darkened(0.35)
	for y in [172.0, 196.0]:
		draw_rect(Rect2(36, y - 5, 648, 10), dark)
		draw_rect(Rect2(36, y - 3, 648, 6), wood)
	for x in range(50, 690, 64):
		_round_rect(Rect2(x - 9, 150, 18, 62), wood, 6, dark, 3)


func _ellipse(at: Vector2, r: float, squash: float, color: Color) -> void:
	draw_set_transform(at, 0, Vector2(1, squash))
	draw_circle(Vector2.ZERO, r, color)
	draw_set_transform(Vector2.ZERO)


# 影（地面に落ちる平たい楕円）
func _shadow(at: Vector2, r: float, alpha := 1.0) -> void:
	_ellipse(at, r, 0.32, Color(0, 0, 0, 0.16 * alpha))


func _round_rect(r: Rect2, color: Color, radius: int, border := Color.TRANSPARENT, width := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if width > 0:
		sb.border_color = border
		sb.set_border_width_all(width)
	draw_style_box(sb, r)


# ふちどりつきの丸をまとめて描く。先に全部のふちを描いてから中身を塗るので、重なってもつながって見える
# items: [[位置, 半径, 色], ...]
func _blobs(items: Array, alpha := 1.0) -> void:
	var line := Color(0.3, 0.2, 0.12, 0.6 * alpha)
	for it in items:
		draw_circle(it[0], it[1] + 3, line)
	for it in items:
		var col: Color = it[2]
		col.a = alpha
		draw_circle(it[0], it[1], col)


func _draw_effect(e: Dictionary) -> void:
	var t: float = e.t
	var at: Vector2 = e.pos
	match e.kind:
		"dust":  # 耕したときの土ぼこり
			for k in 6:
				var dir := Vector2.RIGHT.rotated(k * TAU / 6 + 0.4)
				draw_circle(at + dir * (20 + 50 * t), 10 * (1 - t), Color(0.6, 0.45, 0.28, 1 - t))
		"splash":  # 水やりの水しぶき（上に飛んで落ちる）
			for k in 7:
				var x := (k - 3) * 14.0
				var y := -90 * t + 140 * t * t - absf(x) * 0.3
				draw_circle(at + Vector2(x * (0.5 + t), y), 8 * (1 - t * 0.5), Color(0.55, 0.82, 1.0, 1 - t * t))
		"pop":  # 収穫した作物がぴょこっと跳ねて消える
			var y := -120 * t + 60 * t * t
			var scale := 0.7 + 0.3 * sin(t * PI)
			draw_set_transform(at + Vector2(0, y), 0, Vector2.ONE * scale)
			_draw_ripe(e.crop, Color(crops[e.crop].color, 1 - t * t), Vector2.ZERO, 1 - t * t)
			draw_set_transform(Vector2.ZERO)
		"text":  # ふわっと上がる文字
			var c: Color = e.get("color", Color(1, 1, 1))
			c.a = 1 - t * t
			var pos := at + Vector2(-150, -40 * t)
			draw_string_outline(FONT, pos, e.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 28, 8, Color(0.25, 0.18, 0.1, c.a))
			draw_string(FONT, pos, e.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 28, c)


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
		_round_rect(rect, Color(0.42, 0.63, 0.34), 16, Color(0.36, 0.55, 0.29), 3)
		draw_string(FONT, rect.position + Vector2(0, PLOT / 2 + 10), "タップで耕す", HORIZONTAL_ALIGNMENT_CENTER, PLOT, 18, Color(1, 1, 1, 0.35))
		return
	var soil := Color(0.45, 0.3, 0.18) if p.watered else Color(0.68, 0.5, 0.32)
	_round_rect(Rect2(rect.position + Vector2(0, 6), rect.size), Color(0, 0, 0, 0.15), 16)  # 影
	_round_rect(rect, soil, 16, soil.darkened(0.25), 3)
	# うね（畝）: 暗い線の下に明るい線で、もこっとして見える
	for k in 3:
		var y := rect.position.y + 32 + k * 40
		draw_line(Vector2(rect.position.x + 16, y), Vector2(rect.end.x - 16, y), soil.darkened(0.22), 5)
		draw_line(Vector2(rect.position.x + 16, y + 5), Vector2(rect.end.x - 16, y + 5), soil.lightened(0.1), 2)
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
		var top := c + Vector2(0, 20 - 30 * t)
		var droop := Vector2.ZERO  # 葉っぱのたれ具合
		if not p.watered:
			# 水をあげてない: 葉っぱがしおれて、色も少し黄色っぽい
			leaf = Color(0.62, 0.7, 0.3)
			top = c + Vector2(4 * t, 20 - 22 * t)
			droop = Vector2(0, 12 * t)
		draw_line(c + Vector2(0, 20), top, leaf.darkened(0.3), 4)
		_blobs([[top + Vector2(-12 * t, 0) + droop, 12 * t, leaf], [top + Vector2(12 * t, 0) + droop, 12 * t, leaf]])
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


# alpha: 透明度（収穫の演出で薄くしながら消すとき）
func _draw_ripe(id: String, color: Color, c: Vector2, alpha := 1.0) -> void:
	var leaf := Color(0.3, 0.68, 0.3)
	var shine := Color(1, 1, 1, 0.55 * alpha)  # ツヤ
	if alpha >= 1.0:
		_shadow(c + Vector2(0, 38), 36)
	match id:
		"turnip":
			_blobs([[c + Vector2(-14, -36), 13, leaf], [c + Vector2(14, -36), 13, leaf], [c + Vector2(0, -44), 11, leaf]], alpha)
			draw_line(c + Vector2(0, 30), c + Vector2(2, 44), Color(0.85, 0.8, 0.85, alpha), 3)  # ひげ根
			_blobs([[c, 34, color]], alpha)
			_blobs([[c + Vector2(0, -20), 20, Color(0.72, 0.38, 0.78)]], alpha)
			draw_circle(c + Vector2(-13, 6), 7, shine)
		"tomato":
			draw_line(c + Vector2(0, 42), c + Vector2(0, -46), leaf.darkened(0.3), 5)
			var fruits := [c + Vector2(-22, -18), c + Vector2(20, -4), c + Vector2(-14, 24)]
			_blobs(fruits.map(func(o): return [o, 20, color]), alpha)
			for o in fruits:
				draw_circle(o + Vector2(0, -18), 5, Color(leaf, alpha))  # へた
				draw_circle(o + Vector2(-7, -5), 5, shine)
		"strawberry":
			_blobs([[c + Vector2(-10, -32), 11, leaf], [c + Vector2(10, -32), 11, leaf]], alpha)
			var body := PackedVector2Array([c + Vector2(-35, -14), c + Vector2(35, -14), c + Vector2(0, 42)])
			var outline := Color(0.3, 0.2, 0.12, 0.6 * alpha)
			draw_polyline(body + PackedVector2Array([body[0]]), outline, 6)
			_blobs([[c + Vector2(-17, -12), 18, color], [c + Vector2(17, -12), 18, color]], alpha)
			draw_colored_polygon(body, Color(color, alpha))
			for o in [Vector2(-12, -6), Vector2(10, -2), Vector2(0, 14), Vector2(-4, -16), Vector2(16, -16), Vector2(-18, -18)]:
				draw_circle(c + o, 2.5, Color(1, 0.9, 0.4, alpha))
			draw_circle(c + Vector2(-20, -16), 5, shine)
	# 収穫できる合図のキラキラ
	if alpha < 1.0:
		return
	draw_string_outline(FONT, c + Vector2(30, -40), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 6, Color(0.6, 0.4, 0.1, 0.6))
	draw_string(FONT, c + Vector2(30, -40), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.95, 0.4))


func _draw_drop(at: Vector2) -> void:
	var blue := Color(0.35, 0.65, 1.0)
	draw_circle(at + Vector2(0, 6), 8, blue)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 4), at + Vector2(7, 4), at + Vector2(0, -10)]), blue)


func _draw_box() -> void:
	var r := BOX_RECT
	var wood := Color(0.72, 0.5, 0.3)
	var dark := Color(0.42, 0.26, 0.13)
	_shadow(r.get_center() + Vector2(0, r.size.y / 2 + 4), 70)
	_round_rect(r, wood, 10, dark, 4)
	for x in [r.position.x + 40, r.position.x + 80]:  # 板のすき間
		draw_line(Vector2(x, r.position.y + 32), Vector2(x, r.end.y - 6), wood.darkened(0.2), 2)
	_round_rect(Rect2(r.position, Vector2(r.size.x, 30)), wood.lightened(0.12), 10, dark, 4)  # ふた
	draw_string_outline(FONT, r.position + Vector2(0, 72), "出荷箱", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, 6, dark)
	draw_string(FONT, r.position + Vector2(0, 72), "出荷箱", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color(1, 0.97, 0.9))
	if shipped_count > 0:
		draw_circle(r.position + Vector2(r.size.x, 0), 22, Color(1, 1, 1))
		draw_circle(r.position + Vector2(r.size.x, 0), 19, Color(0.9, 0.3, 0.3))
		draw_string(FONT, r.position + Vector2(r.size.x - 20, 9), str(shipped_count), HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color.WHITE)
