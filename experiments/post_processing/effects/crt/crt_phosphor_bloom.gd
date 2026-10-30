@tool
class_name CRTPhosphorBloom
extends Node

const REFERENCE_HEIGHT: float = 1080.0

var _effect: PostProcessEffect
var _context: PassSourceContext
var _main_viewport: Viewport
var _layer_index: int
var _bloom_material: ShaderMaterial
var _bloom_pass_index: int
var _core_viewport: SubViewport
var _viewports: Array[SubViewport] = []
var _materials: Array[ShaderMaterial] = []
var _attached_canvases: Dictionary[RID, WeakRef] = {}
var _replayed_passes: Dictionary[PassSourceContext.Pass, ColorRect] = {}
var _replayed_copies: Dictionary[PassSourceContext.Pass, BackBufferCopy] = {}


func initialize(
	effect: PostProcessEffect,
	context: PassSourceContext,
	bloom_material: ShaderMaterial,
	bloom_pass_index: int,
) -> void:
	_effect = effect
	_context = context
	_main_viewport = context.main_viewport
	_layer_index = context.layer_index
	_bloom_material = bloom_material
	_bloom_pass_index = bloom_pass_index


func _ready() -> void:
	_core_viewport = _create_viewport("Emission")
	_core_viewport.world_2d = _main_viewport.world_2d
	_replay_core()

	var source := _create_filter("Source", _core_viewport.get_texture(), 0)
	var near_horizontal := _create_filter("NearHorizontal", source.get_texture(), 1)
	var near_vertical := _create_filter("NearVertical", near_horizontal.get_texture(), 2)
	var far_horizontal := _create_filter("FarHorizontal", source.get_texture(), 1)
	var far_vertical := _create_filter("FarVertical", far_horizontal.get_texture(), 2)
	_bloom_material.set_shader_parameter(&"source_texture", source.get_texture())
	_bloom_material.set_shader_parameter(&"near_texture", near_vertical.get_texture())
	_bloom_material.set_shader_parameter(&"far_texture", far_vertical.get_texture())

	_effect.changed.connect(_on_effect_changed, CONNECT_DEFERRED)
	_sync_viewports()
	_update_parameters()
	_update_enabled_state()


func _process(_delta: float) -> void:
	_sync_viewports()
	_update_enabled_state()
	for preceding: PassSourceContext.Pass in _replayed_passes:
		var is_enabled := preceding.is_enabled()
		_replayed_passes[preceding].visible = is_enabled
		_replayed_copies[preceding].visible = is_enabled


func _exit_tree() -> void:
	if _effect.changed.is_connected(_on_effect_changed):
		_effect.changed.disconnect(_on_effect_changed)
	for canvas: RID in _attached_canvases:
		if _attached_canvases[canvas].get_ref() != null:
			RenderingServer.viewport_remove_canvas(_core_viewport.get_viewport_rid(), canvas)
	_attached_canvases.clear()


func _on_effect_changed() -> void:
	# A queued Resource notification can outlive a PostProcessing rebuild.
	if not is_inside_tree():
		return
	_update_parameters()
	_update_enabled_state()


func _create_viewport(viewport_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.size = Vector2i(_main_viewport.get_visible_rect().size)
	viewport.use_hdr_2d = true
	viewport.disable_3d = true
	viewport.transparent_bg = _main_viewport.transparent_bg
	viewport.canvas_cull_mask = _main_viewport.canvas_cull_mask
	viewport.canvas_item_default_texture_filter = _main_viewport.canvas_item_default_texture_filter
	viewport.canvas_item_default_texture_repeat = _main_viewport.canvas_item_default_texture_repeat
	add_child(viewport)
	_viewports.append(viewport)
	return viewport


func _replay_core() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Core"
	layer.layer = _layer_index
	_core_viewport.add_child(layer)

	# Replay only the passes up to this Core, including preceding effects on its layer.
	# The current-frame dependency chain avoids feeding yesterday's Bloom back into itself.
	for preceding: PassSourceContext.Pass in _context.preceding_passes:
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		copy.visible = preceding.is_enabled()
		layer.add_child(copy)
		_replayed_copies[preceding] = copy
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = preceding.material
		rect.visible = preceding.is_enabled()
		layer.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_replayed_passes[preceding] = rect


func _create_filter(
	filter_name: String,
	input_texture: Texture2D,
	stage: int,
) -> SubViewport:
	var viewport := _create_viewport(filter_name)
	var material := ShaderMaterial.new()
	material.shader = _bloom_material.shader
	material.set_shader_parameter(&"source_texture", input_texture)
	material.set_shader_parameter(&"pass_stage", stage)
	material.set_shader_parameter(&"gaussian_axis", Vector2.DOWN if stage == 2 else Vector2.RIGHT)
	_materials.append(material)

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	viewport.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return viewport


func _update_parameters() -> void:
	for material: ShaderMaterial in _materials:
		_effect.apply_to_pass(material, _bloom_pass_index)
	var scale_factor := float(_core_viewport.size.y) / REFERENCE_HEIGHT
	var near_width: float = _effect.get(&"phosphor_bloom_near_width") * scale_factor
	var far_width: float = _effect.get(&"phosphor_bloom_far_width") * scale_factor
	for index in [1, 2]:
		_materials[index].set_shader_parameter(&"gaussian_fwhm", near_width)
	for index in [3, 4]:
		_materials[index].set_shader_parameter(&"gaussian_fwhm", far_width)


func _sync_viewports() -> void:
	var viewport_size := Vector2i(_main_viewport.get_visible_rect().size)
	if _core_viewport.size != viewport_size:
		for viewport: SubViewport in _viewports:
			viewport.size = viewport_size
		_update_parameters()
	_core_viewport.canvas_transform = _main_viewport.canvas_transform
	_core_viewport.global_canvas_transform = _main_viewport.global_canvas_transform
	_core_viewport.snap_2d_transforms_to_pixel = _main_viewport.snap_2d_transforms_to_pixel
	_core_viewport.snap_2d_vertices_to_pixel = _main_viewport.snap_2d_vertices_to_pixel

	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if scene_root == null:
		return
	var current_canvases: Dictionary[RID, bool] = {}
	for node: Node in scene_root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer.get_viewport() != _main_viewport or layer.layer >= _layer_index:
			continue
		if layer.custom_viewport != null and layer.custom_viewport != _main_viewport:
			continue
		var canvas := layer.get_canvas()
		current_canvases[canvas] = true
		if not _attached_canvases.has(canvas):
			RenderingServer.viewport_attach_canvas(_core_viewport.get_viewport_rid(), canvas)
			_attached_canvases[canvas] = weakref(layer)
		RenderingServer.viewport_set_canvas_stacking(
			_core_viewport.get_viewport_rid(), canvas, layer.layer, 0
		)
		# Shared canvases retain their World2D parent, which already applies camera follow.
		RenderingServer.viewport_set_canvas_transform(
			_core_viewport.get_viewport_rid(), canvas, layer.transform
		)
	for canvas: RID in _attached_canvases.keys():
		if not current_canvases.has(canvas):
			if _attached_canvases[canvas].get_ref() != null:
				RenderingServer.viewport_remove_canvas(_core_viewport.get_viewport_rid(), canvas)
			_attached_canvases.erase(canvas)


func _update_enabled_state() -> void:
	var is_enabled := _context.is_enabled()
	for viewport: SubViewport in _viewports:
		viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if is_enabled else SubViewport.UPDATE_DISABLED
		)
