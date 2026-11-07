extends Node2D

# テンプレの起点。ここから作り始める。
# UI 文字列は ASCII のみにすること（Godot 標準フォントに日本語グリフが無く
# Web だと豆腐になる。日本語を出したいなら日本語フォントを同梱してテーマに設定）。


func _ready() -> void:
	var v: String = Engine.get_version_info().string
	$HUD/Label.text = "It works!\nGodot %s" % v
	print("template ready — Godot ", v)
