extends SceneTree
# note の「スキ」のお礼カードの画像（800×600）を作る。
# 使い方: godot --path . --script res://tools/make_thanks.gd -- <出力.png>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 600)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var card: Node2D = load("res://tools/thanks_card.gd").new()
	card.crops = load("res://scenes/main.gd").CROPS
	vp.add_child(card)
	# 大きなカブ（★つき）。_draw_ripe の中で描く位置がリセットされるので、別のノードにして置く
	var turnip: Node2D = load("res://tools/thanks_card.gd").new()
	turnip.crops = card.crops
	turnip.only_turnip = true
	turnip.position = Vector2(540, 400)
	turnip.scale = Vector2(2.3, 2.3)
	vp.add_child(turnip)
	var lala: Node2D = load("res://scenes/player.gd").new()
	lala.position = Vector2(270, 400)
	lala.scale = Vector2(3.4, 3.4)
	lala.bounds = Rect2(0, 0, 9999, 9999)
	vp.add_child(lala)
	await create_timer(0.3).timeout
	lala._clock = 1.0  # まばたきしていないところ
	lala.set_process(false)
	lala.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
