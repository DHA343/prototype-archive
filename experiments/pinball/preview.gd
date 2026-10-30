extends Control

const VIEW_SIZE: Vector2 = Vector2(640, 360)

@onready var _display: SubViewportContainer = $Display
@onready var _viewport: SubViewport = $Display/Viewport


func _ready() -> void:
	# 見た目だけを斜め視点の比率へ変換し、2D物理の座標・形状は変えない。
	_viewport.canvas_transform = Transform2D(Vector2(1.08, 0), Vector2(0, 1), Vector2(-25.6, 0))
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	# プロジェクト側の拡大も含め、画面上で各ドットが整数pxになる倍率を選ぶ。
	var pixel_scale := get_viewport().get_stretch_transform().get_scale()
	var available := size * pixel_scale
	var factor := minf(available.x / VIEW_SIZE.x, available.y / VIEW_SIZE.y)
	if factor >= 1.0:
		factor = floorf(factor)
	_display.scale = Vector2.ONE * factor / pixel_scale
	_display.position = ((available - VIEW_SIZE * factor) * 0.5).floor() / pixel_scale
