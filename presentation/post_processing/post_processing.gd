@tool
class_name PostProcessing
extends Node

@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value
		_apply_enabled_state()

## Processes the whole screen drawn through Layer 1, including preceding layers.
@export var layer_1_effects: Array[PostProcessEffect] = []:
	set(value):
		layer_1_effects = value

		if _is_initialized:
			rebuild_effects()

## Processes the whole screen drawn through Layer 2, including Layer 1 and its effects.
@export var layer_2_effects: Array[PostProcessEffect] = []:
	set(value):
		layer_2_effects = value

		if _is_initialized:
			rebuild_effects()
 
var _is_initialized: bool = false
var _effect_bindings: Array[EffectBinding] = []
var _generated_layers: Array[CanvasLayer] = []
var _generated_sources: Array[Node] = []


func _ready() -> void:
	_is_initialized = true
	rebuild_effects()


func _exit_tree() -> void:
	_disconnect_effects()
	_clear_pass_sources(true)
	_clear_generated_layers(true)
	_is_initialized = false


func rebuild_effects() -> void:
	_disconnect_effects()
	_clear_pass_sources()
	_clear_generated_layers()

	var registered_effects: Dictionary[int, bool] = {}

	_build_effect_layer(&"Layer1Effects", RenderLayers.LAYER_1_EFFECTS, layer_1_effects, registered_effects)
	_build_effect_layer(
		&"Layer2Effects",
		RenderLayers.LAYER_2_EFFECTS,
		layer_2_effects,
		registered_effects,
	)

	_apply_enabled_state()


func _on_effect_changed(binding: EffectBinding) -> void:
	if not _effect_bindings.has(binding):
		return

	for effect_binding in _effect_bindings:
		if effect_binding.effect != binding.effect:
			continue
		if (
			not is_instance_valid(effect_binding.back_buffer_copy)
			or not is_instance_valid(effect_binding.rect)
			or not is_instance_valid(effect_binding.material)
		):
			continue

		_set_binding_enabled(
			effect_binding,
			effect_binding.effect.enabled and effect_binding.effect.is_pass_enabled(effect_binding.pass_index),
		)
		effect_binding.effect.apply_to_pass(effect_binding.material, effect_binding.pass_index)


func _build_effect_layer(
	layer_name: StringName,
	layer_index: int,
	effects: Array[PostProcessEffect],
	registered_effects: Dictionary[int, bool],
) -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = layer_name
	canvas_layer.layer = layer_index
	add_child(canvas_layer, false, Node.INTERNAL_MODE_BACK)
	_generated_layers.append(canvas_layer)

	for index in effects.size():
		var effect := effects[index]

		if not _validate_effect(effect, layer_name, index, registered_effects):
			continue

		registered_effects[effect.get_instance_id()] = true
		_create_effect_nodes(canvas_layer, effect, index)


func _validate_effect(
	effect: PostProcessEffect,
	layer_name: StringName,
	index: int,
	registered_effects: Dictionary[int, bool],
) -> bool:
	if effect == null:
		push_warning("PostProcessing ignored a null effect at %s[%d]." % [layer_name, index])
		return false

	var instance_id := effect.get_instance_id()

	if registered_effects.has(instance_id):
		push_warning("PostProcessing ignored a duplicate Resource at %s[%d]." % [layer_name, index])
		return false

	if effect.get_pass_count() < 1:
		push_warning("PostProcessing ignored an effect without passes at %s[%d]." % [layer_name, index])
		return false
	for pass_index in effect.get_pass_count():
		if effect.get_pass_shader(pass_index) == null:
			push_warning(
				"PostProcessing ignored an effect without a Shader at %s[%d], pass %d."
				% [layer_name, index, pass_index]
			)
			return false

	return true


func _create_effect_nodes(
	canvas_layer: CanvasLayer,
	effect: PostProcessEffect,
	index: int,
) -> void:
	for pass_index in effect.get_pass_count():
		var pass_suffix := "" if pass_index == 0 else "Pass%d" % pass_index
		var back_buffer_copy := BackBufferCopy.new()
		back_buffer_copy.name = "BackBufferCopy%d%s" % [index, pass_suffix]
		back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		canvas_layer.add_child(back_buffer_copy, false, Node.INTERNAL_MODE_BACK)

		var material := ShaderMaterial.new()
		material.shader = effect.get_pass_shader(pass_index)

		var rect := ColorRect.new()
		rect.name = "Effect%d%s" % [index, pass_suffix]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = material
		canvas_layer.add_child(rect, false, Node.INTERNAL_MODE_BACK)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var binding := EffectBinding.new()
		binding.effect = effect
		binding.pass_index = pass_index
		binding.back_buffer_copy = back_buffer_copy
		binding.rect = rect
		binding.material = material
		_effect_bindings.append(binding)

		_set_binding_enabled(binding, effect.enabled and effect.is_pass_enabled(pass_index))
		effect.apply_to_pass(material, pass_index)
		var context := _create_pass_source_context(canvas_layer.layer, rect)
		var source := effect.create_pass_source(pass_index, context, material)
		if source != null:
			add_child(source, false, Node.INTERNAL_MODE_BACK)
			_generated_sources.append(source)
		if pass_index == 0:
			binding.changed_callback = _on_effect_changed.bind(binding)
			effect.changed.connect(binding.changed_callback, CONNECT_DEFERRED)


func _create_pass_source_context(layer_index: int, rect: ColorRect) -> PassSourceContext:
	var preceding: Array[PassSourceContext.Pass] = []
	for binding in _effect_bindings:
		if binding.rect == rect:
			break
		var layer := binding.rect.get_parent() as CanvasLayer
		if layer.layer == layer_index:
			preceding.append(PassSourceContext.Pass.new(
				binding.material, binding.rect.is_visible_in_tree
			))
	return PassSourceContext.new(get_viewport(), layer_index, preceding, rect.is_visible_in_tree)


func _set_binding_enabled(binding: EffectBinding, is_enabled: bool) -> void:
	binding.back_buffer_copy.visible = is_enabled
	binding.rect.visible = is_enabled


func _disconnect_effects() -> void:
	for binding in _effect_bindings:
		if (
			binding.pass_index == 0
			and binding.changed_callback.is_valid()
			and is_instance_valid(binding.effect)
			and binding.effect.changed.is_connected(binding.changed_callback)
		):
			binding.effect.changed.disconnect(binding.changed_callback)

		binding.changed_callback = Callable()

	_effect_bindings.clear()


func _clear_generated_layers(is_immediate: bool = false) -> void:
	for canvas_layer in _generated_layers:
		if not is_instance_valid(canvas_layer):
			continue

		if canvas_layer.get_parent() == self:
			remove_child(canvas_layer)

		if is_immediate:
			canvas_layer.free()
		else:
			canvas_layer.queue_free()

	_generated_layers.clear()


func _clear_pass_sources(is_immediate: bool = false) -> void:
	for source in _generated_sources:
		if not is_instance_valid(source):
			continue
		if source.get_parent() == self:
			remove_child(source)

		if is_immediate:
			source.free()
		else:
			source.queue_free()

	_generated_sources.clear()


func _apply_enabled_state() -> void:
	for canvas_layer in _generated_layers:
		if is_instance_valid(canvas_layer):
			canvas_layer.visible = enabled


class EffectBinding:
	var effect: PostProcessEffect
	var pass_index: int
	var back_buffer_copy: BackBufferCopy
	var rect: ColorRect
	var material: ShaderMaterial
	var changed_callback: Callable
