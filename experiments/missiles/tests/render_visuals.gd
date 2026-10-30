extends "res://experiments/missiles/visuals.gd"
## 計測用。演出処理を変えず、描画コマンド生成のCPU時間を集計する。

static var draw_usec: int = 0


func _draw() -> void:
	var started := Time.get_ticks_usec()
	super._draw()
	draw_usec += Time.get_ticks_usec() - started
