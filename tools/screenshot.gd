extends SceneTree
# 見た目確認用: 少し遊んだ状態にしてスクショを保存する
# 使い方: godot --path . --resolution 720x1280 --script res://tools/screenshot.gd -- <出力.png> [start|grow|result]
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "start"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.2).timeout
	if mode != "start":
		# 1日目: 9マス耕して、カブ3・トマト2・イチゴ1をまいて水やり
		var plan := ["turnip", "turnip", "turnip", "tomato", "tomato", "strawberry", "", "", ""]
		for i in 9:
			main._work(i)
			if plan[i] != "":
				main.selected_seed = plan[i]
				main._work(i)
				main._work(i)
		for d in (2 if mode == "grow" else 5):
			main._on_sleep_pressed()
			await create_timer(0.6).timeout
			if mode == "grow" and d == 1:
				break
			main._on_popup_pressed()
			await create_timer(0.6).timeout
			for i in 9:
				main._work(i)  # 収穫できれば収穫、できなければ水やり
				if main.field.plots[i].crop == "" and main.field.plots[i].tilled and main.money >= 10:
					main.selected_seed = "turnip"
					main._work(i)
					main._work(i)
			main._ship()
		if mode == "grow":
			main._on_popup_pressed()
			await create_timer(0.6).timeout
			main.player.position = Vector2(300, 800)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	print("money=", main.money, " day=", main.day)
	quit()
