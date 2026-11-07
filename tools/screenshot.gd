extends SceneTree
# 見た目確認用: 少し遊んだ状態にしてスクショを保存する
# 使い方: godot --path . --resolution 720x1280 --script res://tools/screenshot.gd -- <出力.png> [title|grow|result]
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "title"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.2).timeout
	if mode != "title":
		main._start("goal" if mode == "grow" else "days")
		await create_timer(0.6).timeout
		# 1日目: 9マス耕して、カブ3・トマト2・イチゴ1をまいて水やり
		var plan := ["turnip", "turnip", "turnip", "tomato", "tomato", "strawberry", "", "", ""]
		for i in 9:
			main._work(i)
			if plan[i] != "":
				main.selected_seed = plan[i]
				main._work(i)
				main._work(i)
		var days: int = 2 if mode == "grow" else main.DAYS_LIMIT
		for d in days:
			main._on_sleep_pressed()
			await create_timer(0.5).timeout
			if main.popup_buttons.get_child_count() != 1:
				break  # 結果画面
			main._wake_up()
			await create_timer(0.5).timeout
			if mode == "grow" and d == days - 1:
				break
			for i in 9:
				main._work(i)  # 収穫できれば収穫、できなければ水やり
				if main.field.plots[i].crop == "" and main.field.plots[i].tilled and main.money >= 10:
					main.selected_seed = "turnip"
					main._work(i)
					main._work(i)
			main._ship()
		main.player.position = Vector2(300, 800)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	print("money=", main.money, " day=", main.day)
	quit()
