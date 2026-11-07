extends SceneTree
# バランス確認用: いくつかの作戦を自動で遊ばせて、30日の所持金と3000Gまでの日数を出す
# 使い方: godot --headless --path . --script res://tools/simulate.gd
const MAIN := preload("res://scenes/main.gd")


func _initialize() -> void:
	var crops: Dictionary = MAIN.CROPS
	for name in ["カブだけ", "トマトだけ", "イチゴだけ", "高い順に買えるもの"]:
		var r := _play(crops, name)
		print("%s: 30日で %dG / 3000Gまで %s" % [name, r[0], ("%d日" % r[1]) if r[1] > 0 else "届かない"])
	quit()


# 作戦ごとに、空いた畑にまく種を決める
func _choose(crops: Dictionary, name: String, money: int) -> String:
	var order: Array = {"カブだけ": ["turnip"], "トマトだけ": ["tomato"], "イチゴだけ": ["strawberry"]}.get(name, ["strawberry", "tomato", "turnip"])
	for id in order:
		if money >= crops[id].seed:
			return id
	return ""


# 毎日: 収穫 → 出荷 → 空いた畑にまく → 全部に水 → 寝る（main.gd と同じルール）
func _play(crops: Dictionary, name: String) -> Array:
	var money: int = MAIN.START_MONEY
	var plots := []
	for i in 9:
		plots.append({"crop": "", "growth": 0})
	var money_at_30 := 0
	var goal_day := 0
	for day in range(1, 200):
		var earned := 0
		for p in plots:
			if p.crop != "" and p.growth >= crops[p.crop].days:
				earned += crops[p.crop].price
				p.crop = ""
		for p in plots:
			if p.crop == "":
				var id := _choose(crops, name, money)
				if id != "":
					money -= crops[id].seed
					p.crop = id
					p.growth = 0
		for p in plots:
			if p.crop != "":
				p.growth += 1
		money += earned  # 寝ると出荷したぶんが入る
		if day == MAIN.DAYS_LIMIT:
			money_at_30 = money
		if goal_day == 0 and money >= MAIN.GOAL_MONEY:
			goal_day = day
		if day >= MAIN.DAYS_LIMIT and goal_day > 0:
			break
	return [money_at_30, goal_day]
