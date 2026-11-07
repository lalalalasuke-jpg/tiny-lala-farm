extends Node2D

# Tiny Lala Farm: 畑を育てて、出荷でお金をためるゲーム。
# 畑をタップ → ららすけが歩いていって、その畑に合った作業をする
#   （耕す → 種をまく → 水やり → 収穫）。収穫したものは出荷箱へ。寝ると次の日。
# モードは2つ: 30日でいくら稼げるか（days）／3000Gを何日でためられるか（goal）

const DAYS_LIMIT := 30
const GOAL_MONEY := 3000
const START_MONEY := 100
const CROPS := {
	"turnip": {"name": "カブ", "seed": 10, "days": 2, "price": 30, "color": Color(0.97, 0.95, 0.97)},
	"tomato": {"name": "トマト", "seed": 20, "days": 3, "price": 70, "color": Color(0.9, 0.2, 0.15)},
	"strawberry": {"name": "イチゴ", "seed": 40, "days": 4, "price": 160, "color": Color(0.95, 0.25, 0.35)},
}
const SEED_ORDER := ["turnip", "tomato", "strawberry"]
const NONE := -1  # 歩き終わっても何もしない
const BOX := 99  # 歩き終わったら出荷箱に入れる

# 「もう一回」でシーンを読み直しても残るように static にする。空ならタイトルから
static var next_mode := ""

var mode := ""  # "days" か "goal"
var day := 1
var money := START_MONEY
var bag := {}  # 収穫して持っているもの（作物id → 個数）
var shipped := {}  # 今日出荷箱に入れたもの（寝るとお金になる）
var selected_seed := "turnip"
var pending := NONE
var busy := false  # 寝ている途中など、操作を受け付けない

@onready var field: Node2D = $Field
@onready var player: Node2D = $Player

var day_label: Label
var money_label: Label
var bag_label: Label
var message_label: Label
var seed_buttons := {}
var sleep_button: Button
var fade: ColorRect
var popup: PanelContainer
var popup_label: Label
var popup_buttons: VBoxContainer


func _ready() -> void:
	var plots := []
	for i in 9:
		plots.append({"tilled": false, "crop": "", "growth": 0, "watered": false})
	field.plots = plots
	field.crops = CROPS
	player.bounds = field.WALK_AREA.grow(-30)
	player.position = Vector2(360, 880)
	player.arrived.connect(_on_arrived)
	_build_ui()
	busy = true
	if next_mode != "":
		_start(next_mode)
	else:
		fade.color.a = 0.6
		_refresh()
		_show_popup("Tiny Lala Farm\n\nどっちで遊ぶ？", [
			["%d日チャレンジ\n%d日でいくら稼げる？" % [DAYS_LIMIT, DAYS_LIMIT], _start.bind("days")],
			["%dGチャレンジ\n何日でためられる？" % GOAL_MONEY, _start.bind("goal")],
		])


func _start(m: String) -> void:
	mode = m
	popup.visible = false
	_refresh()
	say("畑をタップすると、歩いていって耕すよ")
	await _fade_to(0.0)
	busy = false


# ---------------------------------------------------------------- 操作

func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(make_input_local(event).position)
	elif event.is_action_pressed("ui_accept"):
		_act_here()


func _on_tap(pos: Vector2) -> void:
	var i: int = field.plot_at(pos)
	if i >= 0:
		pending = i
		player.walk_to(field.plot_center(i))
	elif field.near_box(pos):
		pending = BOX
		player.walk_to(field.box_stand_point())
	elif field.WALK_AREA.has_point(pos):
		pending = NONE
		player.walk_to(pos)


func _on_arrived() -> void:
	var what := pending
	pending = NONE
	if what == BOX:
		_ship()
	elif what >= 0:
		_work(what)


# キーボード（スペース/Enter）: 足元の畑か、近くの出荷箱
func _act_here() -> void:
	var i: int = field.plot_at(player.position)
	if i >= 0:
		_work(i)
	elif field.near_box(player.position):
		_ship()


# ---------------------------------------------------------------- 畑仕事

func _work(i: int) -> void:
	var p: Dictionary = field.plots[i]
	if not p.tilled:
		p.tilled = true
		say("耕したよ！下で種をえらんで、もう一回タップしてまこう")
	elif p.crop == "":
		var c: Dictionary = CROPS[selected_seed]
		if money < c.seed:
			say("お金が足りないよ（%sの種は %dG）" % [c.name, c.seed])
			return
		money -= c.seed
		p.crop = selected_seed
		p.growth = 0
		p.watered = false
		say("%sの種をまいたよ。水をあげてね" % c.name)
	else:
		var c: Dictionary = CROPS[p.crop]
		if p.growth >= c.days:
			bag[p.crop] = bag.get(p.crop, 0) + 1
			p.crop = ""
			p.growth = 0
			p.watered = false
			say("%sを収穫！出荷箱に持っていこう" % c.name)
		elif not p.watered:
			p.watered = true
			say("水をあげたよ。あと%d日で収穫" % (c.days - p.growth))
		else:
			say("今日はもう水やりしたよ。寝ると育つよ")
	_refresh()


func _ship() -> void:
	if bag.is_empty():
		say("かばんが空っぽだよ。育った作物を収穫してね")
		return
	for id in bag:
		shipped[id] = shipped.get(id, 0) + bag[id]
	bag.clear()
	say("出荷箱に入れたよ。寝るとお金になるよ")
	_refresh()


# ---------------------------------------------------------------- 1日の終わり

func _on_sleep_pressed() -> void:
	if busy:
		return
	busy = true
	pending = NONE
	player.walking = false
	await _fade_to(1.0)
	var earned := 0
	var lines := []
	for id in shipped:
		var c: Dictionary = CROPS[id]
		earned += c.price * shipped[id]
		lines.append("%s×%d　%dG" % [c.name, shipped[id], c.price * shipped[id]])
	shipped.clear()
	money += earned
	for p in field.plots:
		if p.crop != "" and p.watered:
			p.growth = min(p.growth + 1, CROPS[p.crop].days)
		p.watered = false
	day += 1
	_refresh()
	var text := "出荷: なし"
	if not lines.is_empty():
		text = "出荷: +%dG\n%s" % [earned, "\n".join(lines)]
	if mode == "days" and day > DAYS_LIMIT:
		_finish("%d日間おつかれさま！\n\n%s\n\nさいごの所持金\n%dG" % [DAYS_LIMIT, text, money])
	elif mode == "goal" and money >= GOAL_MONEY:
		_finish("%dG達成！\n\n%s\n\nかかった日数\n%d日" % [GOAL_MONEY, text, day - 1])
	elif mode == "goal" and _stuck():
		_finish("お金も作物もなくなっちゃった…\n\n%d日目 所持金 %dG" % [day, money])
	else:
		_show_popup("%d日目の朝\n\n%s\n\n所持金 %dG" % [day, text, money], [["畑へ行く", _wake_up]])


func _wake_up() -> void:
	popup.visible = false
	await _fade_to(0.0)
	busy = false
	if mode == "days" and day == DAYS_LIMIT:
		say("今日が最終日！収穫したものは出荷箱へ")
	else:
		say("おはよう！水やりを忘れずにね")


func _finish(text: String) -> void:
	_show_popup(text, [["もう一回", _restart.bind(mode)], ["タイトルへ", _restart.bind("")]])


func _restart(m: String) -> void:
	next_mode = m
	get_tree().reload_current_scene()


# これ以上どうやっても進めない（種が買えない・育つ作物も売る物もない）
func _stuck() -> bool:
	if money >= CROPS.turnip.seed or not bag.is_empty() or not shipped.is_empty():
		return false
	for p in field.plots:
		if p.crop != "":
			return false
	return true


func _fade_to(alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, 0.4)
	await tw.finished


# ---------------------------------------------------------------- 画面

func say(text: String) -> void:
	message_label.text = text


func _refresh() -> void:
	if mode == "goal":
		day_label.text = "%d日目　目標 %dG" % [day, GOAL_MONEY]
	else:
		day_label.text = "%d日目 / %d" % [min(day, DAYS_LIMIT), DAYS_LIMIT]
	money_label.text = "%dG" % money
	var items := []
	for id in SEED_ORDER:
		if bag.has(id):
			items.append("%s×%d" % [CROPS[id].name, bag[id]])
	bag_label.text = "かばん: " + ("からっぽ" if items.is_empty() else "  ".join(items))
	var n := 0
	for id in shipped:
		n += shipped[id]
	field.shipped_count = n
	field.queue_redraw()


func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var top := _rect(hud, Rect2(0, 0, 720, 130), Color(0.98, 0.94, 0.84))
	day_label = _label(top, Rect2(24, 12, 340, 60), 40, Color(0.35, 0.25, 0.15))
	money_label = _label(top, Rect2(360, 12, 336, 60), 40, Color(0.75, 0.5, 0.05))
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bag_label = _label(top, Rect2(24, 74, 672, 44), 26, Color(0.4, 0.32, 0.22))

	var bottom := _rect(hud, Rect2(0, 990, 720, 290), Color(0.98, 0.94, 0.84))
	message_label = _label(bottom, Rect2(24, 8, 672, 64), 26, Color(0.35, 0.25, 0.15))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var group := ButtonGroup.new()
	for k in SEED_ORDER.size():
		var id: String = SEED_ORDER[k]
		var c: Dictionary = CROPS[id]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == selected_seed
		b.text = "%s\n種 %dG\n%d日 → %dG" % [c.name, c.seed, c.days, c.price]
		b.position = Vector2(24 + k * 228, 78)
		b.size = Vector2(216, 110)
		b.add_theme_font_size_override("font_size", 22)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				selected_seed = id
				say("%sの種をえらんだよ。耕した畑をタップしてまこう" % c.name))
		bottom.add_child(b)
		seed_buttons[id] = b

	sleep_button = Button.new()
	sleep_button.text = "寝る（次の日へ）"
	sleep_button.position = Vector2(24, 200)
	sleep_button.size = Vector2(672, 72)
	sleep_button.add_theme_font_size_override("font_size", 30)
	sleep_button.pressed.connect(_on_sleep_pressed)
	bottom.add_child(sleep_button)

	fade = _rect(hud, Rect2(0, 0, 720, 1280), Color(0.05, 0.05, 0.15, 0.0))

	popup = PanelContainer.new()
	popup.position = Vector2(110, 360)
	popup.custom_minimum_size = Vector2(500, 0)
	popup.visible = false
	hud.add_child(popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	popup.add_child(box)
	popup_label = Label.new()
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.add_theme_font_size_override("font_size", 30)
	box.add_child(popup_label)
	popup_buttons = VBoxContainer.new()
	popup_buttons.add_theme_constant_override("separation", 16)
	box.add_child(popup_buttons)


# buttons: [["ボタンの文字", 押したときの Callable], ...]
func _show_popup(text: String, buttons: Array) -> void:
	popup_label.text = text
	for b in popup_buttons.get_children():
		popup_buttons.remove_child(b)
		b.queue_free()
	for spec in buttons:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(spec[1])
		popup_buttons.add_child(b)
	popup.visible = true
	popup.reset_size()
	popup.position.y = (1280 - popup.size.y) / 2


func _rect(parent: Node, r: Rect2, color: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	return cr


func _label(parent: Node, r: Rect2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
