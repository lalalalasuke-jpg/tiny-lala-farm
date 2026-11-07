extends SceneTree
# バランス確認用: いくつかの作戦を自動で遊ばせて、30日の所持金と3000Gまでの日数を出す
# 毎日ちゃんと水やりする前提（枯れる確率は WITHER_WATERED、収穫の当たりは CARED の確率）。
# 運があるので RUNS 回の平均。
# 使い方: godot --headless --path . --script res://tools/simulate.gd
const MAIN := preload("res://scenes/main.gd")
const RUNS := 300
const DAYS := 30  # 日数チャレンジの長さ
const GOAL := 3000  # 金額チャレンジの目標

# 作戦: 9マスそれぞれに何をまくか、どの作物に肥料を使うか
const PLANS := {
	"カブだけ": {"plots": ["turnip", "turnip", "turnip", "turnip", "turnip", "turnip", "turnip", "turnip", "turnip"], "fert": []},
	"イチゴだけ": {"plots": ["strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": []},
	"イチゴだけ＋肥料": {"plots": ["strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["strawberry"]},
	"セット狙い(2:3:4)": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": []},
	"セット狙い＋イチゴに肥料": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["strawberry"]},
	"セット狙い＋全部に肥料": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["turnip", "tomato", "strawberry"]},
}


func _initialize() -> void:
	for name in PLANS:
		var total_money := 0.0
		var total_days := 0.0
		for r in RUNS:
			var res := _play(PLANS[name])
			total_money += res[0]
			total_days += res[1]
		print("%s: 30日で 平均%dG / 3000Gまで 平均%.1f日" % [name, total_money / RUNS, total_days / RUNS])
	quit()


# 毎日: 収穫 → 出荷 → 空いた畑にまく（お金が足りなければ待つ）→ 肥料 → 水 → 寝る
func _play(plan: Dictionary) -> Array:
	var crops: Dictionary = MAIN.CROPS
	var money: int = MAIN.START_MONEY
	var plots := []
	for i in 9:
		plots.append({"crop": "", "growth": 0, "fert": false, "dead": false})
	var money_at_30 := 0
	var goal_day := 0
	for day in range(1, 300):
		var earned := 0
		var counts := {}
		for p in plots:
			if p.dead:
				p.crop = ""
				p.dead = false
			if p.crop != "" and p.growth >= _need(p):
				var n := 2 if randf() < MAIN.DOUBLE_CARED else 1
				var price: float = crops[p.crop].price * (MAIN.GOOD_RATE if randf() < MAIN.GOOD_CARED else 1.0)
				earned += roundi(price) * n
				counts[p.crop] = counts.get(p.crop, 0) + n
				p.crop = ""
		var sets := 1 << 30
		for id in MAIN.SEED_ORDER:
			sets = min(sets, counts.get(id, 0))
		earned += sets * MAIN.SET_BONUS
		for i in 9:
			var p: Dictionary = plots[i]
			var id: String = plan.plots[i]
			if p.crop == "" and money >= crops[id].seed:
				money -= crops[id].seed
				p.crop = id
				p.growth = 0
				p.fert = false
			if p.crop != "" and not p.fert and p.crop in plan.fert and money >= MAIN.FERT_PRICE:
				money -= MAIN.FERT_PRICE
				p.fert = true
		for p in plots:
			if p.crop != "" and p.growth < _need(p):
				if not p.fert and randf() < MAIN.WITHER_WATERED:
					p.dead = true
				else:
					p.growth += 1
		money += earned
		if day == DAYS:
			money_at_30 = money
		if goal_day == 0 and money >= GOAL:
			goal_day = day
		if day >= DAYS and goal_day > 0:
			break
	return [money_at_30, goal_day]


func _need(p: Dictionary) -> int:
	var d: int = MAIN.CROPS[p.crop].days
	return max(1, d - 1) if p.fert else d
