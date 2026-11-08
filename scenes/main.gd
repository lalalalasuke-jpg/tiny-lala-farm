extends Node2D

# Tiny Lala Farm: 畑を育てて、出荷でお金をためるゲーム。
# 畑をタップ → ららすけが歩いていって、その畑に合った作業をする
#   （耕す → 種をまく → 水やり → 収穫）。収穫したものは出荷箱へ。寝ると次の日。
# モードは2つ: 30日でいくら稼げるか（days）／3000Gを何日でためられるか（goal）

const DAY_OPTIONS := [20, 30, 50, 60]  # 日数チャレンジの長さ
const GOAL_OPTIONS := [3000, 5000, 10000]  # 金額チャレンジの目標
const BEST_PATH := "user://best.cfg"  # ベスト記録（Web ではブラウザの中に保存される）
# 効果音のセット。kenney = 無料素材（CC0、sfx/kenney）、code = コードで作った音（tools/make_sfx.py）
const SFX_SETS := ["kenney", "code", "off"]
const SFX_NAMES := {"kenney": "音: 素材", "code": "音: コード", "off": "音: なし"}
const START_MONEY := 100
const FERT_PRICE := 15
const WITHER_WATERED := 0.05  # 水をあげた夜に枯れる確率
const WITHER_DRY := 0.3  # 水やりを忘れた夜に枯れる確率
# 収穫の当たり。植えてから一度も水やりを忘れなかった（お世話かんぺき）と当たりやすい
const GOOD_CARED := 0.3  # ★品質のいいもの（GOOD_RATE 倍で売れる）
const GOOD_BASE := 0.05
const DOUBLE_CARED := 0.25  # 2個とれる
const DOUBLE_BASE := 0.05
const GOOD_RATE := 1.5
const SET_BONUS := 150  # 出荷箱にカブ・トマト・イチゴがそろうと「野菜セット」でボーナス
const CROPS := {
	"turnip": {"name": "カブ", "seed": 10, "days": 2, "price": 30, "color": Color(0.97, 0.95, 0.97)},
	"tomato": {"name": "トマト", "seed": 20, "days": 3, "price": 70, "color": Color(0.9, 0.2, 0.15)},
	"strawberry": {"name": "イチゴ", "seed": 40, "days": 4, "price": 120, "color": Color(0.95, 0.25, 0.35)},
}
const SEED_ORDER := ["turnip", "tomato", "strawberry"]
const BOX := 99  # 予約の行き先: 出荷箱
const QUEUE_MAX := 12

# 「もう一回」でシーンを読み直しても残るように static にする。空ならタイトルから
static var next_mode := ""
static var next_limit := 0

var mode := ""  # "days" か "goal"
var limit := 0  # days なら日数、goal なら目標金額
var best_path := BEST_PATH  # テストでは別のファイルに差し替える
var day := 1
var money := START_MONEY
# 収穫して持っているもの／今日出荷箱に入れたもの（寝るとお金になる）。
# キーは作物id。★品質のものは "turnip★" のように★を付けて分ける。値は個数
var bag := {}
var shipped := {}
var selected_seed := "turnip"
# タップの予約。{"at": 畑の番号 か BOX, "use": タップした時にえらんでいた種か肥料}。
# 先頭から順に歩いていって作業する
var queue: Array = []
var sfx_set := "kenney"
var _sfx_cache := {}
var _sfx_players: Array = []
var _sfx_next := 0
var busy := false  # 寝ている途中など、操作を受け付けない

@onready var field: Node2D = $Field
@onready var player: Node2D = $Player

var day_label: Label
var money_label: Label
var bag_label: Label
var message_label: Label
var seed_buttons := {}
var sfx_button: Button
var sleep_button: Button
var fade: ColorRect
var popup: PanelContainer
var popup_label: Label
var popup_buttons: VBoxContainer


func _ready() -> void:
	var plots := []
	for i in 9:
		plots.append({"tilled": false, "crop": "", "growth": 0, "watered": false, "fert": false, "dead": false, "missed": false})
	field.plots = plots
	field.crops = CROPS
	player.bounds = field.WALK_AREA.grow(-30)
	player.position = Vector2(360, 880)
	player.arrived.connect(_on_arrived)
	player.canceled.connect(_clear_queue)
	_build_ui()
	var cfg := ConfigFile.new()
	if cfg.load(best_path) == OK:
		sfx_set = cfg.get_value("settings", "sfx", sfx_set)
	sfx_button.text = SFX_NAMES[sfx_set]
	busy = true
	if next_mode != "":
		_start(next_mode, next_limit)
	else:
		fade.color.a = 0.6
		_refresh()
		_show_title()


func _show_title() -> void:
	_show_popup("Tiny Lala Farm\n\nどっちで遊ぶ？", [
		["日数チャレンジ\n決まった日数でいくら稼げる？", _show_lengths.bind("days")],
		["金額チャレンジ\n目標金額を何日でためられる？", _show_lengths.bind("goal")],
	])


func _show_lengths(m: String) -> void:
	var buttons := []
	for n in (DAY_OPTIONS if m == "days" else GOAL_OPTIONS):
		var best := _load_best(m, n)
		var label := "%d日" % n if m == "days" else "%dG" % n
		if best > 0:
			label += "　（ベスト %s）" % _format_score(m, best)
		buttons.append([label, _start.bind(m, n)])
	buttons.append(["もどる", _show_title])
	_show_popup("日数をえらんでね" if m == "days" else "目標金額をえらんでね", buttons)


func _start(m: String, n: int) -> void:
	mode = m
	limit = n
	popup.visible = false
	_refresh()
	say("畑をタップすると歩いていって耕すよ。続けてタップすると順番にやるよ")
	await _fade_to(0.0)
	busy = false


# ---------------------------------------------------------------- 効果音

func sfx(name: String) -> void:
	if sfx_set == "off":
		return
	var path := "res://sfx/%s/%s.%s" % [sfx_set, name, "ogg" if sfx_set == "kenney" else "wav"]
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path)
	if _sfx_players.is_empty():
		for k in 4:  # 4つまで重ねて鳴らせる
			var pl := AudioStreamPlayer.new()
			add_child(pl)
			_sfx_players.append(pl)
	var player_: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	player_.stream = _sfx_cache[path]
	player_.play()


func _on_sfx_pressed() -> void:
	sfx_set = SFX_SETS[(SFX_SETS.find(sfx_set) + 1) % SFX_SETS.size()]
	sfx_button.text = SFX_NAMES[sfx_set]
	var cfg := ConfigFile.new()
	cfg.load(best_path)
	cfg.set_value("settings", "sfx", sfx_set)
	cfg.save(best_path)
	sfx("harvest")


# ---------------------------------------------------------------- 操作

func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(make_input_local(event).position)
	elif event.is_action_pressed("ui_accept"):
		_act_here()


# 畑か出荷箱をタップすると予約に足す（歩いている途中でも前の作業は消えない）。
# 草のところをタップすると、予約を取り消してそこへ歩く
func _on_tap(pos: Vector2) -> void:
	var i: int = field.plot_at(pos)
	if i < 0 and field.near_box(pos):
		i = BOX
	if i < 0:
		if field.WALK_AREA.has_point(pos):
			_clear_queue()
			player.walk_to(pos)
		return
	if queue.size() >= QUEUE_MAX:
		say("予約がいっぱいだよ。草のところをタップすると取り消せるよ")
		return
	queue.append({"at": i, "use": selected_seed})
	_show_queue()
	if queue.size() == 1:
		_walk_next()


func _walk_next() -> void:
	if queue.is_empty():
		return
	var at: int = queue[0].at
	player.walk_to(field.box_stand_point() if at == BOX else field.plot_center(at))


func _on_arrived() -> void:
	if queue.is_empty():
		return
	var job: Dictionary = queue.pop_front()
	if job.at == BOX:
		_ship()
	else:
		_work(job.at, job.use)
	_show_queue()
	_walk_next()


func _clear_queue() -> void:
	queue.clear()
	_show_queue()


func _show_queue() -> void:
	field.queued = queue.map(func(j): return j.at)
	field.queue_redraw()


# キーボード（スペース/Enter）: 足元の畑か、近くの出荷箱
func _act_here() -> void:
	var i: int = field.plot_at(player.position)
	if i >= 0:
		_work(i)
	elif field.near_box(player.position):
		_ship()


# ---------------------------------------------------------------- 畑仕事

# use: まく種か "fert"（肥料）。省略すると今えらんでいるもの
func _work(i: int, use := "") -> void:
	if use == "":
		use = selected_seed
	var p: Dictionary = field.plots[i]
	var at: Vector2 = field.plot_center(i)
	if not p.tilled:
		p.tilled = true
		sfx("till")
		field.add_effect("dust", at)
		say("耕したよ！下で種をえらんで、もう一回タップしてまこう")
	elif p.dead:
		p.crop = ""
		p.dead = false
		p.fert = false
		sfx("clear")
		field.add_effect("dust", at)
		say("枯れた作物を片付けたよ")
	elif p.crop == "":
		if use == "fert":
			sfx("error")
			say("肥料は育っている作物に使うよ。種をえらんでまこう")
			return
		var c: Dictionary = CROPS[use]
		if money < c.seed:
			sfx("error")
			say("お金が足りないよ（%sの種は %dG）" % [c.name, c.seed])
			return
		money -= c.seed
		p.crop = use
		p.growth = 0
		p.watered = false
		p.missed = false
		sfx("sow")
		field.add_effect("text", at, {"text": "-%dG" % c.seed, "color": Color(1, 0.85, 0.5)})
		say("%sの種をまいたよ。水をあげてね" % c.name)
	else:
		var c: Dictionary = CROPS[p.crop]
		var need: int = field.days_needed(p)
		if p.growth >= need:
			_harvest(i)
		elif use == "fert" and not p.fert:
			if money < FERT_PRICE:
				sfx("error")
				say("お金が足りないよ（肥料は %dG）" % FERT_PRICE)
				return
			money -= FERT_PRICE
			p.fert = true
			sfx("fert")
			field.add_effect("text", at, {"text": "-%dG" % FERT_PRICE, "color": Color(1, 0.85, 0.5)})
			say("肥料をあげたよ。もう枯れないし、1日早く育つよ")
		elif not p.watered:
			p.watered = true
			sfx("water")
			field.add_effect("splash", at)
			say("水をあげたよ。あと%d日で収穫" % (need - p.growth))
		else:
			say("今日はもう水やりしたよ。寝ると育つよ")
	_refresh()


func _harvest(i: int) -> void:
	var p: Dictionary = field.plots[i]
	var cared: bool = not p.missed
	var good := randf() < (GOOD_CARED if cared else GOOD_BASE)
	var count := 2 if randf() < (DOUBLE_CARED if cared else DOUBLE_BASE) else 1
	var key: String = p.crop + ("★" if good else "")
	bag[key] = bag.get(key, 0) + count
	var text := "%sを収穫！" % _item_name(key)
	if good and count == 2:
		text = "やった！品質のいい%sが2個もとれた！" % CROPS[p.crop].name
	elif good:
		text = "品質のいい%sがとれた！高く売れるよ" % CROPS[p.crop].name
	elif count == 2:
		text = "%sが2個とれた！" % CROPS[p.crop].name
	say(text + "出荷箱に持っていこう")
	var at: Vector2 = field.plot_center(i)
	sfx("good" if good or count == 2 else "harvest")
	field.add_effect("pop", at, {"crop": p.crop})
	var label: String = ("★" if good else "") + CROPS[p.crop].name + ("×2" if count == 2 else "")
	field.add_effect("text", at + Vector2(0, -60), {"text": label, "color": Color(1, 0.95, 0.4) if good else Color.WHITE})
	p.crop = ""
	p.growth = 0
	p.watered = false
	p.fert = false


func _ship() -> void:
	if bag.is_empty():
		sfx("error")
		say("かばんが空っぽだよ。育った作物を収穫してね")
		return
	sfx("ship")
	var n := 0
	for key in bag:
		n += bag[key]
	field.add_effect("text", field.BOX_RECT.get_center() + Vector2(0, -60), {"text": "%d個 出荷！" % n, "color": Color(1, 0.95, 0.4)})
	for key in bag:
		shipped[key] = shipped.get(key, 0) + bag[key]
	bag.clear()
	var sets := _count_sets(shipped)
	if sets > 0:
		say("出荷箱に入れたよ。野菜セット×%dができてる！寝るとお金になるよ" % sets)
	else:
		say("出荷箱に入れたよ。カブ・トマト・イチゴがそろうと野菜セットでボーナス！")
	_refresh()


# ---------------------------------------------------------------- 作物アイテム

# 表示用の並び: カブ → ★カブ → トマト → …
func _sorted_keys(items: Dictionary) -> Array:
	var keys := []
	for id in SEED_ORDER:
		for key in [id, id + "★"]:
			if items.get(key, 0) > 0:
				keys.append(key)
	return keys


func _crop_of(key: String) -> String:
	return key.trim_suffix("★")


func _item_name(key: String) -> String:
	return ("★" if key.ends_with("★") else "") + CROPS[_crop_of(key)].name


func _item_price(key: String) -> int:
	var price: int = CROPS[_crop_of(key)].price
	return roundi(price * GOOD_RATE) if key.ends_with("★") else price


# items の中で、カブ・トマト・イチゴ1つずつのセットがいくつ作れるか（品質は問わない）
func _count_sets(items: Dictionary) -> int:
	var sets := 1 << 30
	for id in SEED_ORDER:
		sets = min(sets, items.get(id, 0) + items.get(id + "★", 0))
	return sets


# ---------------------------------------------------------------- 1日の終わり

func _on_sleep_pressed() -> void:
	if busy:
		return
	busy = true
	_clear_queue()
	player.walking = false
	await _fade_to(1.0)
	var earned := 0
	var lines := []
	for key in _sorted_keys(shipped):
		var g: int = _item_price(key) * shipped[key]
		earned += g
		lines.append("%s×%d　%dG" % [_item_name(key), shipped[key], g])
	var sets := _count_sets(shipped)
	if sets > 0:
		earned += SET_BONUS * sets
		lines.append("野菜セット×%d　ボーナス %dG" % [sets, SET_BONUS * sets])
	shipped.clear()
	money += earned
	var withered := {}
	for p in field.plots:
		if p.crop != "" and not p.dead and p.growth < field.days_needed(p):
			# 肥料なしの作物は、夜のうちに枯れることがある（水やりを忘れると枯れやすい）
			if not p.fert and randf() < (WITHER_WATERED if p.watered else WITHER_DRY):
				p.dead = true
				withered[p.crop] = withered.get(p.crop, 0) + 1
			elif p.watered:
				p.growth += 1
			if not p.watered:
				p.missed = true  # 水やりを忘れた（収穫の当たりが出にくくなる）
		p.watered = false
	day += 1
	_refresh()
	var text := "出荷: なし"
	if not lines.is_empty():
		text = "出荷: +%dG\n%s" % [earned, "\n".join(lines)]
	if not withered.is_empty():
		var w := []
		for id in withered:
			w.append("%s×%d" % [CROPS[id].name, withered[id]])
		text += "\n\n枯れちゃった: " + "  ".join(w)
	if mode == "days" and day > limit:
		_finish("%d日間おつかれさま！\n\n%s\n\nさいごの所持金\n%dG" % [limit, text, money], money)
	elif mode == "goal" and money >= limit:
		_finish("%dG達成！\n\n%s\n\nかかった日数\n%d日" % [limit, text, day - 1], day - 1)
	elif mode == "goal" and _stuck():
		_finish("お金も作物もなくなっちゃった…\n\n%d日目 所持金 %dG" % [day, money])
	else:
		_show_popup("%d日目の朝\n\n%s\n\n所持金 %dG" % [day, text, money], [["畑へ行く", _wake_up]])


func _wake_up() -> void:
	popup.visible = false
	await _fade_to(0.0)
	busy = false
	sfx("morning")
	if mode == "days" and day == limit:
		say("今日が最終日！収穫したものは出荷箱へ")
	else:
		say("おはよう！水やりを忘れずにね")


# score: days なら所持金（多いほどいい）、goal ならかかった日数（少ないほどいい）。-1 は記録なし
func _finish(text: String, score := -1) -> void:
	if score >= 0:
		var best := _load_best(mode, limit)
		var better := best <= 0 or (score > best if mode == "days" else score < best)
		if better:
			_save_best(mode, limit, score)
			text += "\n\nベスト更新！" if best > 0 else "\n\nはじめての記録！"
		else:
			text += "\n\nベスト %s" % _format_score(mode, best)
	_show_popup(text, [["もう一回", _restart.bind(mode, limit)], ["タイトルへ", _restart.bind("", 0)]])


func _restart(m: String, n: int) -> void:
	next_mode = m
	next_limit = n
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- ベスト記録

func _best_key(m: String, n: int) -> String:
	return "%s_%d" % [m, n]


func _load_best(m: String, n: int) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(best_path) != OK:
		return 0
	return cfg.get_value("best", _best_key(m, n), 0)


func _save_best(m: String, n: int, score: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(best_path)  # 無ければ空のまま
	cfg.set_value("best", _best_key(m, n), score)
	cfg.save(best_path)


func _format_score(m: String, score: int) -> String:
	return "%dG" % score if m == "days" else "%d日" % score


# これ以上どうやっても進めない（種が買えない・育つ作物も売る物もない）
func _stuck() -> bool:
	if money >= CROPS.turnip.seed or not bag.is_empty() or not shipped.is_empty():
		return false
	for p in field.plots:
		if p.crop != "" and not p.dead:
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
		day_label.text = "%d日目　目標 %dG" % [day, limit]
	elif mode == "days":
		day_label.text = "%d日目 / %d" % [min(day, limit), limit]
	else:
		day_label.text = ""
	money_label.text = "%dG" % money
	var items := []
	for key in _sorted_keys(bag):
		items.append("%s×%d" % [_item_name(key), bag[key]])
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
	bag_label = _label(top, Rect2(24, 74, 520, 44), 26, Color(0.4, 0.32, 0.22))
	bag_label.clip_text = true
	sfx_button = Button.new()
	sfx_button.position = Vector2(556, 76)
	sfx_button.size = Vector2(140, 44)
	sfx_button.add_theme_font_size_override("font_size", 20)
	sfx_button.pressed.connect(_on_sfx_pressed)
	top.add_child(sfx_button)

	var bottom := _rect(hud, Rect2(0, 990, 720, 290), Color(0.98, 0.94, 0.84))
	message_label = _label(bottom, Rect2(24, 8, 672, 64), 26, Color(0.35, 0.25, 0.15))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var group := ButtonGroup.new()
	var items: Array = SEED_ORDER + ["fert"]
	for k in items.size():
		var id: String = items[k]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == selected_seed
		var hint := ""
		if id == "fert":
			b.text = "肥料\n%dG\n枯れない\n1日早い" % FERT_PRICE
			hint = "肥料をえらんだよ。育っている作物をタップしてあげよう"
		else:
			var c: Dictionary = CROPS[id]
			b.text = "%s\n種 %dG\n%d日\n→ %dG" % [c.name, c.seed, c.days, c.price]
			hint = "%sの種をえらんだよ。耕した畑をタップしてまこう" % c.name
		b.position = Vector2(24 + k * 171, 76)
		b.size = Vector2(159, 116)
		b.add_theme_font_size_override("font_size", 19)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				selected_seed = id
				sfx("click")
				say(hint))
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
