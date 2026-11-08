extends SceneTree
# バランス確認用: いくつかの作戦を自動で遊ばせて、30日の所持金と3000Gまでの日数を出す
# 毎日ちゃんと水やりする前提（枯れる確率は WITHER_WATERED、収穫の当たりは CARED の確率）。
# 運があるので RUNS 回の平均。
# 使い方: godot --headless --path . --script res://tools/simulate.gd
const MAIN := preload("res://scenes/main.gd")
const RUNS := 300
const DAYS := 30  # 日数チャレンジの長さ
const GOALS := [3000, 5000, 10000]  # 金額チャレンジの目標

# 作戦: 9マスそれぞれに何をまくか、どの作物に肥料を使うか
const PLANS := {
	"カブだけ": {"plots": ["turnip", "turnip", "turnip", "turnip", "turnip", "turnip", "turnip", "turnip", "turnip"], "fert": []},
	"イチゴだけ": {"plots": ["strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": []},
	"イチゴだけ＋肥料": {"plots": ["strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["strawberry"]},
	"セット狙い(2:3:4)": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": []},
	"セット狙い＋イチゴに肥料": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["strawberry"]},
	"セット狙い＋全部に肥料": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["turnip", "tomato", "strawberry"]},
	# 買い足し: お金が「値段＋buy」以上あれば、朝に売り地を1マス買う。増えた畑には EXTRA の順にまく
	"セット狙い＋全部に肥料＋買い足し": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["turnip", "tomato", "strawberry"], "buy": 200},
	"同＋買い足し(10日目まで)": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["turnip", "tomato", "strawberry"], "buy": 200, "until": 10},
	"同＋買い足し(20日目まで)": {"plots": ["turnip", "turnip", "tomato", "tomato", "tomato", "strawberry", "strawberry", "strawberry", "strawberry"], "fert": ["turnip", "tomato", "strawberry"], "buy": 200, "until": 20},
}
const EXTRA := ["strawberry", "tomato", "turnip", "strawberry", "tomato", "strawberry", "turnip"]
const MAX_PLOTS := 16


func _initialize() -> void:
	print("売り地: %dG から買うたびに +%dG" % [MAIN.BUY_BASE, MAIN.BUY_STEP])
	for name in PLANS:
		var total_money := 0.0
		var total_days := [0.0, 0.0, 0.0]
		for r in RUNS:
			var res := _play(PLANS[name])
			total_money += res[0]
			for g in GOALS.size():
				total_days[g] += res[1][g]
		var goal_text := " / ".join(range(GOALS.size()).map(func(g): return "%dG %.1f日" % [GOALS[g], total_days[g] / RUNS]))
		print("%s: 30日で 平均%dG（畑%.1fマス）/ %s" % [name, total_money / RUNS, _plots_sum / RUNS, goal_text])
		_plots_sum = 0.0
	quit()


# 毎日: 収穫 → 出荷 → 空いた畑にまく（お金が足りなければ待つ）→ 肥料 → 水 → 寝る
var _plots_sum := 0.0


func _play(plan: Dictionary) -> Array:
	var crops: Dictionary = MAIN.CROPS
	var money: int = MAIN.START_MONEY
	var plots := []
	for i in 9:
		plots.append({"crop": "", "growth": 0, "fert": false, "dead": false})
	var money_at_30 := 0
	var goal_days := [0, 0, 0]
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
		var price: int = MAIN.BUY_BASE + MAIN.BUY_STEP * (plots.size() - 9)
		if plan.has("buy") and day <= plan.get("until", 999) and plots.size() < MAX_PLOTS and money >= price + plan.buy:
			money -= price
			plots.append({"crop": "", "growth": 0, "fert": false, "dead": false})
		for i in plots.size():
			var p: Dictionary = plots[i]
			var id: String = plan.plots[i] if i < 9 else EXTRA[i - 9]
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
			_plots_sum += plots.size()
		for g in GOALS.size():
			if goal_days[g] == 0 and money >= GOALS[g]:
				goal_days[g] = day
		if day >= DAYS and goal_days[-1] > 0:
			break
	return [money_at_30, goal_days]


func _need(p: Dictionary) -> int:
	var d: int = MAIN.CROPS[p.crop].days
	return max(1, d - 1) if p.fert else d
