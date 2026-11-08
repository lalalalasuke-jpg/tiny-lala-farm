extends "res://scenes/field.gd"
# note の「スキ」のお礼カード（800×600）の絵。field.gd の描き方（草・花・作物）を使い回す。
# make_thanks.gd から使う

const W := 800.0
const H := 600.0

var only_turnip := false  # true なら大きなカブだけ描く（ノードの位置と大きさで置く）


func _draw() -> void:
	if only_turnip:
		_draw_ripe("turnip", crops.turnip.color, Vector2.ZERO)
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.47, 0.7, 0.38))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 10:
		_ellipse(Vector2(rng.randf_range(0, W), rng.randf_range(160, H)), rng.randf_range(60, 120), 0.45, Color(0.53, 0.75, 0.42, 0.6))
	var petals := [Color(1, 1, 1), Color(1, 0.85, 0.35), Color(1, 0.65, 0.75)]
	for k in 26:
		var at := Vector2(rng.randf_range(20, W - 20), rng.randf_range(170, H - 20))
		if Rect2(150, 220, 520, 340).has_point(at):
			continue
		var col: Color = petals[k % petals.size()]
		for a in 5:
			draw_circle(at + Vector2(7, 0).rotated(a * TAU / 5), 5.5, col)
		draw_circle(at, 4, Color(1, 0.75, 0.2) if col != petals[1] else Color(0.9, 0.5, 0.15))
	# ハート
	for h in [[Vector2(110, 240), 1.6], [Vector2(700, 230), 1.3], [Vector2(660, 540), 1.0], [Vector2(90, 520), 1.1], [Vector2(400, 200), 0.9]]:
		_heart(h[0], h[1])
	# 文字
	var text := "ありがとう！"
	draw_string_outline(FONT, Vector2(0, 140), text, HORIZONTAL_ALIGNMENT_CENTER, W, 96, 22, Color(0.42, 0.26, 0.13))
	draw_string(FONT, Vector2(0, 140), text, HORIZONTAL_ALIGNMENT_CENTER, W, 96, Color(1, 0.98, 0.9))


func _heart(at: Vector2, s: float) -> void:
	var pink := Color(1, 0.45, 0.6)
	var line := Color(0.6, 0.2, 0.3, 0.6)
	for pass_ in 2:
		var col := line if pass_ == 0 else pink
		var g := 3.0 if pass_ == 0 else 0.0
		draw_circle(at + Vector2(-10, 0) * s, 12 * s + g, col)
		draw_circle(at + Vector2(10, 0) * s, 12 * s + g, col)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-21 * s - g, 4 * s), at + Vector2(21 * s + g, 4 * s), at + Vector2(0, 26 * s + g)]), col)
