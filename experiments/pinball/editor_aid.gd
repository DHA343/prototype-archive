@tool
extends RefCounted
## 標準の2D編集を補助し、変更はエディタのUndo履歴へ登録する。


static func board_of(node: Node) -> Node2D:
	var parent := node.get_parent()
	while parent != null:
		if parent.has_method("editor_grid_size"):
			return parent as Node2D
		parent = parent.get_parent()
	return null


static func snap_position(node: Node2D) -> void:
	if not Engine.is_editor_hint():
		return
	var board := board_of(node)
	var grid: int = board.editor_grid_size() if board != null else 8
	var point := board.to_local(node.global_position) if board != null else node.position
	point = point.snapped(Vector2.ONE * grid)
	if board != null:
		point = node.get_parent().to_local(board.to_global(point))
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Snap pinball part", UndoRedo.MERGE_DISABLE, node)
	undo.add_do_property(node, "position", point)
	undo.add_undo_property(node, "position", node.position)
	undo.commit_action()


static func snap_curve(wall: Path2D) -> void:
	if not Engine.is_editor_hint() or wall.curve == null:
		return
	var board := board_of(wall)
	var grid: int = board.editor_grid_size() if board != null else 8
	var pose := board.global_transform.affine_inverse() * wall.global_transform \
		if board != null else wall.transform
	var adjusted := wall.curve.duplicate() as Curve2D
	for index in range(adjusted.point_count):
		var original := adjusted.get_point_position(index)
		var point := pose.affine_inverse() * (pose * original).snapped(Vector2.ONE * grid)
		var incoming := pose * (original + adjusted.get_point_in(index))
		var outgoing := pose * (original + adjusted.get_point_out(index))
		adjusted.set_point_position(index, point)
		adjusted.set_point_in(index, pose.affine_inverse() * incoming.snapped(Vector2.ONE * grid) - point)
		adjusted.set_point_out(index, pose.affine_inverse() * outgoing.snapped(Vector2.ONE * grid) - point)
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Snap pinball curve", UndoRedo.MERGE_DISABLE, wall)
	undo.add_do_property(wall, "curve", adjusted)
	undo.add_undo_property(wall, "curve", wall.curve)
	undo.commit_action()


static func mirror(source: Node2D) -> void:
	if not Engine.is_editor_hint():
		return
	var board := board_of(source)
	if board == null:
		push_warning("Open table.tscn to mirror parts.")
		return
	var target := source.get_node_or_null(NodePath(source.mirror_path)) as Node2D \
		if not source.mirror_path.is_empty() else null
	var created := target == null
	if created:
		target = source.duplicate() as Node2D
		target.name = source.name + "Mirror"
		while source.get_parent().has_node(NodePath(target.name)):
			target.name += "2"
	elif (target == source and not source is Path2D) or target.get_script() != source.get_script():
		push_warning("The mirror partner must be another part of the same type.")
		return
	var values: Dictionary = source.editor_values()
	if target == source:
		# 天井など中央をまたぐ一本の壁は、前半の制御点から後半を揃える。
		var adjusted := source.curve.duplicate() as Curve2D
		for index in range(floori(adjusted.point_count * 0.5)):
			var point := adjusted.get_point_position(index)
			var incoming := point + adjusted.get_point_in(index)
			var outgoing := point + adjusted.get_point_out(index)
			var reflected: Array[Vector2] = []
			for local: Vector2 in [point, incoming, outgoing]:
				var world := board.to_local(source.to_global(local))
				world.x = 640 - world.x
				reflected.append(source.to_local(board.to_global(world)))
			var opposite := adjusted.point_count - 1 - index
			adjusted.set_point_position(opposite, reflected[0])
			adjusted.set_point_in(opposite, reflected[2] - reflected[0])
			adjusted.set_point_out(opposite, reflected[1] - reflected[0])
		var history := EditorInterface.get_editor_undo_redo()
		history.create_action("Mirror pinball ceiling", UndoRedo.MERGE_DISABLE, source)
		history.add_do_property(source, "curve", adjusted)
		history.add_undo_property(source, "curve", source.curve)
		history.commit_action()
		return
	var point := board.to_local(source.global_position)
	point.x = 640 - point.x
	values.position = source.get_parent().to_local(board.to_global(point))
	if source is Path2D:
		var reflected := source.curve.duplicate() as Curve2D
		for index in range(reflected.point_count):
			reflected.set_point_position(index, reflected.get_point_position(index) * Vector2(-1, 1))
			reflected.set_point_in(index, reflected.get_point_in(index) * Vector2(-1, 1))
			reflected.set_point_out(index, reflected.get_point_out(index) * Vector2(-1, 1))
		values.curve = reflected
		values.rotation = -source.rotation
	elif values.has("right_side"):
		values.right_side = not source.right_side
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Mirror pinball part", UndoRedo.MERGE_DISABLE, source)
	if created:
		undo.add_do_method(source.get_parent(), "add_child", target)
		undo.add_do_method(target, "set_owner", EditorInterface.get_edited_scene_root())
		undo.add_do_reference(target)
		undo.add_undo_method(source.get_parent(), "remove_child", target)
	for property: String in values:
		undo.add_do_property(target, property, values[property])
		if not created:
			undo.add_undo_property(target, property, target.get(property))
	var target_path := NodePath("../" + str(target.name))
	var source_path := NodePath("../" + str(source.name))
	undo.add_do_property(source, "mirror_path", target_path)
	undo.add_undo_property(source, "mirror_path", source.mirror_path)
	undo.add_do_property(target, "mirror_path", source_path)
	if not created:
		undo.add_undo_property(target, "mirror_path", target.mirror_path)
	undo.commit_action()


static func add_part(board: Node2D, kind: String) -> void:
	if not Engine.is_editor_hint():
		return
	var scene: PackedScene = load("res://experiments/pinball/bumper.tscn" \
		if kind == "bumper" else "res://experiments/pinball/wall.tscn")
	var node := scene.instantiate() as Node2D
	node.position = Vector2(160, 96)
	if kind == "curve":
		var curve: Curve2D = node.curve.duplicate()
		curve.set_point_out(0, Vector2(32, -24))
		curve.set_point_in(1, Vector2(-32, -24))
		node.curve = curve
	var parent := board.get_node("Bumpers" if kind == "bumper" else "Walls")
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Add pinball part", UndoRedo.MERGE_DISABLE, board)
	undo.add_do_method(parent, "add_child", node, true)
	undo.add_do_method(node, "set_owner", EditorInterface.get_edited_scene_root())
	undo.add_undo_method(parent, "remove_child", node)
	undo.add_do_reference(node)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
