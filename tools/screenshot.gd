extends SceneTree
# 見た目確認用: 少し遊んだ状態にしてスクショを保存する
# 使い方: godot --path . --resolution 720x1280 --script res://tools/screenshot.gd -- <出力.png> [title|howto|credits|lengths|grow|result|queue|showcase|cover]
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "title"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.2).timeout
	if mode == "queue":  # タップの予約: 畑を続けてタップして、歩いている途中を撮る
		main.best_path = "user://test_best.cfg"
		main._start("days", 30)
		await create_timer(0.6).timeout
		for i in [0, 0, 1, 1, 5]:  # 0と1は「耕す→まく」、5は耕すだけ
			main._on_tap(main.field.plot_center(i))
		main.selected_seed = "tomato"  # 予約したあとに種を変えても、予約はカブのまま
		main._on_tap(main.field.BOX_RECT.get_center())
		await create_timer(0.25).timeout
		print("queue=", main.field.queued)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
		await create_timer(4.0).timeout
		var crops := []
		for i in [0, 1, 5]:
			crops.append([main.field.plots[i].tilled, main.field.plots[i].crop])
		print("after=", crops, " queue=", main.queue.size(), " money=", main.money)
		quit()
		return
	if mode == "showcase" or mode == "cover":  # 投稿ページ用: にぎやかな畑を直接作って撮る
		main.best_path = "user://test_best.cfg"
		main._start("days", 30)
		await create_timer(0.6).timeout
		main.day = 12
		main.money = 1840
		main.bag = {"tomato": 2, "strawberry★": 1}
		main.shipped = {"turnip": 3}
		var looks := [
			["strawberry", 4, true, false, false], ["tomato", 3, true, false, false], ["turnip", 2, true, true, false], ["", 0, false, false, false],
			["strawberry", 2, true, false, true], ["tomato", 1, false, false, false], ["turnip", 1, true, false, true], ["", 0, false, false, false],
			["tomato", 3, true, true, false], ["strawberry", 1, true, false, false], ["", 0, true, false, false], ["", 0, false, false, false],
			["", 0, false, false, false], ["", 0, false, false, false], ["", 0, false, false, false], ["", 0, false, false, false],
		]
		for i in 16:
			var p: Dictionary = main.field.plots[i]
			var l: Array = looks[i]
			if i == 3:
				p.owned = true
			if not p.owned:
				continue
			p.tilled = true
			p.crop = l[0]
			p.growth = l[1]
			p.watered = l[2]
			p.fert = l[3]
			p.missed = l[4]
		main.bought = 1
		main._refresh()
		main.say("トマトが2個とれた！出荷箱に持っていこう")
		main.player.position = Vector2(560, 520)
		main.player.face = -1.0
		if mode == "cover":
			main.get_node("Player").visible = true
			var title := Label.new()
			title.text = "Tiny Lala Farm"
			title.add_theme_font_override("font", load("res://fonts/NotoSansJP-Subset.ttf"))
			title.add_theme_font_size_override("font_size", 76)
			title.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
			title.add_theme_color_override("font_outline_color", Color(0.42, 0.26, 0.13))
			title.add_theme_constant_override("outline_size", 18)
			title.position = Vector2(0, 180)
			title.size = Vector2(720, 110)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			main.add_child(title)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if mode == "cover":  # 630×500（itch.io の表紙）: 畑のまわりを切り取って縮める
			img = img.get_region(Rect2i(0, 160, 720, 571))
			img.resize(630, 500, Image.INTERPOLATE_LANCZOS)
		img.save_png(args[0])
		quit()
		return
	if mode == "howto":
		main._show_howto()
	elif mode == "credits":
		main._show_credits()
	elif mode == "lengths":  # 長さえらび（result で保存したテスト用のベストが出る）
		main.best_path = "user://test_best.cfg"
		main._show_lengths("days")
	elif mode != "title":
		main.best_path = "user://test_best.cfg"
		main._start("goal" if mode == "grow" else "days", 3000 if mode == "grow" else 30)
		await create_timer(0.6).timeout
		# 1日目: 9マス耕して、カブ3・トマト2・イチゴ1をまいて水やり
		var plan := ["turnip", "turnip", "turnip", "tomato", "tomato", "strawberry", "", "", ""]
		var own: Array = main.owned_plots()
		for k in own.size():
			var i: int = own[k]
			main._work(i)
			if plan[k] != "":
				main.selected_seed = plan[k]
				main._work(i)
				main._work(i)
		var days: int = 2 if mode == "grow" else 30
		for d in days:
			main._on_sleep_pressed()
			await create_timer(0.5).timeout
			if main.popup_buttons.get_child_count() != 1:
				break  # 結果画面
			main._wake_up()
			await create_timer(0.5).timeout
			if mode == "grow" and d == days - 1:
				break
			for i in main.owned_plots():
				main._work(i)  # 収穫できれば収穫、できなければ水やり
				if main.field.plots[i].crop == "" and main.field.plots[i].tilled and main.money >= 10:
					main.selected_seed = "turnip"
					main._work(i)
					main._work(i)
			main._ship()
		if mode == "grow":  # 枯れた畑と肥料の見た目も確認
			main.field.plots[4].dead = true
			main.field.plots[6].fert = true
			main.field.queue_redraw()
		main.player.position = Vector2(300, 800)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	print("money=", main.money, " day=", main.day)
	quit()
