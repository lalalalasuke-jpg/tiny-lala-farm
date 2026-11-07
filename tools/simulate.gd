extends SceneTree
# バランス確認用: いくつかの作戦を自動で遊ばせて、30日の所持金と3000Gまでの日数を出す
# 毎日ちゃんと水やりする前提（枯れる確率は WITHER_WATERED）。運があるので RUNS 回の平均。
# 使い方: godot --headless --path . --script res://tools/simulate.gd
const MAIN := preload("res://scenes/main.gd")
const RUNS := 300


func _initialize() -> void:
	for seed_plan in [["turnip"], ["tomato"], ["strawberry"], ["strawberry", "tomato", "turnip"]]:
		for fert in [false, true]:
			var total_money := 0.0
			var total_days := 0.0
			for r in RUNS:
				var res := _play(seed_plan, fert)
				total_money += res[0]
				total_days += res[1]
			var name := "→".join(seed_plan.map(func(id): return MAIN.CROPS[id].name))
			print("%-14s 肥料%s: 30日で 平均%dG / 3000Gまで 平均%.1f日" % [name, "あり" if fert else "なし", total_money / RUNS, total_days / RUNS])
	quit()


# 毎日: 収穫 → 出荷 → 空いた畑にまく（買える一番左の種）→ 肥料 → 水 → 寝る
func _play(seed_plan: Array, fert: bool) -> Array:
	var crops: Dictionary = MAIN.CROPS
	var money: int = MAIN.START_MONEY
	var plots := []
	for i in 9:
		plots.append({"crop": "", "growth": 0, "fert": false, "dead": false})
	var money_at_30 := 0
	var goal_day := 0
	for day in range(1, 300):
		var earned := 0
		for p in plots:
			if p.dead:
				p.crop = ""
				p.dead = false
			if p.crop != "" and p.growth >= _need(p):
				earned += crops[p.crop].price
				p.crop = ""
		for p in plots:
			if p.crop == "":
				for id in seed_plan:
					if money >= crops[id].seed:
						money -= crops[id].seed
						p.crop = id
						p.growth = 0
						p.fert = false
						break
			if fert and p.crop != "" and not p.fert and money >= MAIN.FERT_PRICE:
				money -= MAIN.FERT_PRICE
				p.fert = true
		for p in plots:
			if p.crop != "" and p.growth < _need(p):
				if not p.fert and randf() < MAIN.WITHER_WATERED:
					p.dead = true
				else:
					p.growth += 1
		money += earned
		if day == MAIN.DAYS_LIMIT:
			money_at_30 = money
		if goal_day == 0 and money >= MAIN.GOAL_MONEY:
			goal_day = day
		if day >= MAIN.DAYS_LIMIT and goal_day > 0:
			break
	return [money_at_30, goal_day]


func _need(p: Dictionary) -> int:
	var d: int = MAIN.CROPS[p.crop].days
	return max(1, d - 1) if p.fert else d
