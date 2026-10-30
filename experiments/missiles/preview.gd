extends Control

const Arena = preload("res://experiments/missiles/arena.gd")
const Missile = preload("res://experiments/missiles/missile.gd")
const FOCUS_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]
const VIEW_CENTER: Vector2 = Vector2(320, 180)

@export var titles: Array[String] = [
	"MISSILE",
]
@export var details: Array[String] = [
	"Lateral aim point + instability + acceleration",
]

@export var missiles: Array[PackedScene] = []
@export var launcher_scene: PackedScene

var arenas: Array[Node2D] = []
var _cells: Array[Control] = []
var _curved_modes: Array[bool] = []
var _offset_modes: Array[bool] = []
var _focus: int = -1
var _paused: bool = false
var _slow: bool = false
var _dragging: bool = false
var _pointer: Vector2 = Vector2.ZERO
var _show_guidance: bool = false
var _selected_shot: int = -1


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for index in range(missiles.size()):
		var cell := SubViewportContainer.new()
		cell.stretch = false
		cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		_cells.append(cell)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640, 360)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		cell.add_child(viewport)
		var arena := Arena.new()
		var launcher := launcher_scene.instantiate() as Node2D
		launcher.missile_scene = missiles[index]
		var prototype := missiles[index].instantiate() as Node2D
		_curved_modes.append(not prototype is Missile and prototype.is_curved_guidance())
		_offset_modes.append(prototype is Missile)
		prototype.free()
		arena.add_child(launcher)
		viewport.add_child(arena)
		var camera := Camera2D.new()
		camera.position = VIEW_CENTER
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		viewport.add_child(camera)
		launcher.random.seed = 20261028
		arenas.append(arena)
		var label := Label.new()
		label.text = titles[index] + "\n" + details[index]
		label.position = Vector2(10, 5)
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(label)
		var info := Label.new()
		info.name = "GuidanceInfo"
		info.add_theme_font_size_override("font_size", 12)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.visible = false
		cell.add_child(info)
	var help := Label.new()
	help.name = "Help"
	help.add_theme_font_size_override("font_size", 14)
	add_child(help)
	_update_help()
	resized.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	var target := Vector2(-1, -1)
	if _dragging:
		for cell in _cells:
			if cell.visible and cell.get_global_rect().has_point(_pointer):
				var point := cell.get_global_transform().affine_inverse() * _pointer
				var viewport := cell.get_child(0) as SubViewport
				point += VIEW_CENTER - Vector2(viewport.size) * 0.5
				target = Vector2(clampf(point.x, 30, 610), clampf(point.y, 60, 240))
	for arena in arenas:
		arena.target_override = target
		if _paused and target.x >= 0.0 and not arena.target.position.is_equal_approx(target):
			arena.target.position = target
			arena.refresh_guidance()
	_update_guidance_selection()


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse != null:
		_pointer = mouse.position
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode in FOCUS_KEYS and FOCUS_KEYS.find(key.keycode) < arenas.size():
		_focus = FOCUS_KEYS.find(key.keycode)
		_layout()
	match key.keycode:
		KEY_0:
			_focus = -1
			_layout()
		KEY_SPACE:
			for arena in arenas:
				arena.fire()
		KEY_M:
			for arena in arenas:
				arena.moving_target = not arena.moving_target
			_update_help()
		KEY_T:
			for arena in arenas:
				arena.show_traces = not arena.show_traces
		KEY_C:
			_show_guidance = not _show_guidance
			_update_guidance_selection()
			_update_help()
		KEY_P:
			_paused = not _paused
			for arena in arenas:
				arena.process_mode = Node.PROCESS_MODE_DISABLED if _paused else Node.PROCESS_MODE_INHERIT
			_update_help()
		KEY_S:
			_slow = not _slow
			Engine.time_scale = 0.25 if _slow else 1.0
			_update_help()
		KEY_R:
			_replay.call_deferred()


func _replay() -> void:
	_selected_shot = -1
	for arena in arenas:
		arena.reset()
		arena.launcher.random.seed = 20261028


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _update_help() -> void:
	var text := "Drag: Target   Space: Fire   M: Move"
	if arenas.size() > 1:
		text = "1–%d: Enlarge   0: All   " % arenas.size() + text
	text += "   C: Guidance   P: Pause   S: Slow   T: Trails   R: Replay"
	if _show_guidance:
		text += "   [GUIDANCE]"
	if _paused:
		text += "   [PAUSED]"
	if _slow:
		text += "   [0.25x]"
	if not arenas[0].moving_target:
		text += "   [STATIC]"
	$Help.text = text


func _update_guidance_selection() -> void:
	var available: Dictionary = {}
	var pairs: Array[Dictionary] = []
	for arena in arenas:
		var live: Dictionary = {}
		for missile in arena.launcher._missiles:
			if not is_instance_valid(missile) or missile.is_queued_for_deletion():
				continue
			var shot_id: int = missile.get_meta("shot_id")
			live[shot_id] = missile
			available[shot_id] = true
		pairs.append(live)
	if not available.has(_selected_shot):
		_selected_shot = -1 if available.is_empty() else int(available.keys().min())
	for index in range(arenas.size()):
		var info := _cells[index].get_child(2) as Label
		info.visible = _show_guidance
		var snapshot: Dictionary = {}
		var status := "Waiting for missile"
		if _selected_shot >= 0:
			var missile: Node2D = pairs[index].get(_selected_shot)
			status = "Shot %d | Finished" % (_selected_shot + 1)
			if missile != null:
				status = "Shot %d | Launch" % (_selected_shot + 1)
				if _show_guidance:
					snapshot = _get_guidance_snapshot(missile)
				if not snapshot.is_empty():
					status = "Shot %d | %s | Error %+.1f°" % [
						_selected_shot + 1, snapshot.phase, rad_to_deg(snapshot.error)]
		arenas[index].set_guidance(snapshot)
		info.text = status
		if not snapshot.is_empty() and snapshot.curved:
			var departure: Vector2 = snapshot.start_tangent
			var arrival: Vector2 = snapshot.end_tangent
			info.text += "\nTangents: start %.1f / end %.1f px" % [
				departure.length(), arrival.length()]
		if _offset_modes[index]:
			info.text += "\nOffset pursuit | No Hermite"
			info.text += "\nCyan: aim / target  Yellow: aim point"
		elif not _curved_modes[index]:
			info.text += "\nDirect pursuit | No Hermite"
			info.text += "\nCyan: target line  Yellow: target"
		else:
			info.text += "\nCyan: curve  Green: start  Orange: end"
			info.text += "\nYellow: guide"
		info.text += "  Pink: steering"


func _get_guidance_snapshot(missile: Node2D) -> Dictionary:
	if not missile is Missile:
		return missile.get_guidance_snapshot()

	# 比較表示用の点列や旧方式の接線項目は、ミサイル本体へ持ち込まない。
	var state: Dictionary = missile.get_guidance_state()
	if state.is_empty():
		return {}

	return {
		"curved": false,
		"path": PackedVector2Array([state.origin, state.aim, state.target]),
		"start": state.origin, "end": state.target,
		"start_tangent": Vector2.ZERO, "end_tangent": Vector2.ZERO,
		"guide": state.aim, "direction": state.direction,
		"error": state.instability_angle,
		"phase": ("HOLD" if state.instability_active else "REST") if state.instability_enabled else "OFF",
	}


func _layout() -> void:
	var available := size - Vector2(0, 28)
	var slot := available if _focus >= 0 else available / Vector2(arenas.size(), 1)
	var logical_size := Vector2(640, 360)
	var factor := minf(slot.x / logical_size.x, slot.y / logical_size.y)
	var extent := logical_size * factor
	for index in range(_cells.size()):
		var cell := _cells[index]
		cell.visible = _focus < 0 or index == _focus
		var viewport := cell.get_child(0) as SubViewport
		viewport.size = Vector2i(logical_size)
		cell.size = logical_size
		cell.scale = Vector2.ONE * factor
		var origin := Vector2.ZERO if _focus >= 0 else Vector2(index * slot.x, 0)
		cell.position = origin + (slot - extent) * 0.5
		# 一覧で縮小表示しても、見出しを読みやすい大きさに保つ。
		var label := cell.get_child(1) as Label
		label.scale = Vector2.ONE / maxf(factor, 0.1)
		label.position = Vector2(8, 4) / maxf(factor, 0.1)
		label.text = titles[index] if _focus < 0 else titles[index] + "\n" + details[index]
		var info := cell.get_child(2) as Label
		info.scale = label.scale
		var info_y := 28.0 if _focus < 0 else 48.0
		info.position = Vector2(8, info_y) / maxf(factor, 0.1)
	$Help.position = Vector2(8, size.y - 24)




