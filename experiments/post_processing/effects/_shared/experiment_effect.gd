@tool
class_name ExperimentEffect
extends PostProcessEffect

@export var parameters: Dictionary = {}:
	set(value):
		parameters = value
		emit_changed()

var _materials: Array[WeakRef] = []
var _runtime: Dictionary = {}


func get_shader() -> Shader:
	return null


func get_parameter(parameter: StringName) -> Variant:
	if String(parameter).begins_with("has_"):
		return parameters.get(StringName(String(parameter).trim_prefix("has_"))) is Texture2D
	if parameters.has(parameter):
		return parameters[parameter]
	return RenderingServer.shader_get_parameter_default(get_shader().get_rid(), parameter)


func set_parameter(parameter: StringName, value: Variant) -> void:
	parameters[parameter] = value
	if parameter == &"mode":
		notify_property_list_changed()
	reset_history()
	_update_materials()
	emit_changed()


func set_runtime_parameter(parameter: StringName, value: Variant) -> void:
	_runtime[parameter] = value
	for reference in _materials:
		var material := reference.get_ref() as ShaderMaterial
		if material != null:
			material.set_shader_parameter(parameter, value)


func reset_history() -> void:
	set_runtime_parameter(&"history_valid", false)


func get_runtime_parameter(parameter: StringName) -> Variant:
	return _runtime.get(parameter)


func needs_history() -> bool:
	return false


func apply_to_pass(material: ShaderMaterial, _pass_index: int) -> void:
	_materials = _materials.filter(func(reference: WeakRef) -> bool: return reference.get_ref() != null)
	if not _materials.any(func(reference: WeakRef) -> bool: return reference.get_ref() == material):
		_materials.append(weakref(material))
	apply_to(material)
	for parameter: StringName in _runtime:
		material.set_shader_parameter(parameter, _runtime[parameter])


func create_pass_source(
	_pass_index: int,
	context: PassSourceContext,
	material: ShaderMaterial,
) -> Node:
	if not needs_history():
		return null
	var source := preload("history_source.gd").new()
	source.initialize(self, context, material)
	return source


func _update_shader_parameters() -> void:
	for uniform: Dictionary in get_shader().get_shader_uniform_list():
		var parameter := StringName(uniform.name)
		if not _is_runtime(parameter):
			_shader_parameters[parameter] = get_parameter(parameter)


func _update_materials() -> void:
	for reference in _materials:
		var material := reference.get_ref() as ShaderMaterial
		if material != null:
			apply_to_pass(material, 0)


func _is_runtime(parameter: StringName) -> bool:
	return parameter in [
		&"screen_texture", &"history_texture", &"history_valid", &"frame_delta",
		&"mask_texture", &"velocity_texture", &"depth_texture", &"adapted_exposure", &"pyramid_texture",
	]


func _get_property_list() -> Array[Dictionary]:
	# Godot collects this callback from every base script; customize through the helper.
	return _get_parameter_properties()


func _get_parameter_properties() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var shader := get_shader()
	if shader == null:
		return properties
	for uniform: Dictionary in shader.get_shader_uniform_list():
		if _is_runtime(StringName(uniform.name)) or String(uniform.name).begins_with("has_"):
			continue
		var property: Dictionary = uniform.duplicate()
		property.name = "settings/" + String(uniform.name)
		property.usage = PROPERTY_USAGE_EDITOR
		properties.append(property)
	return properties


func _get(property: StringName) -> Variant:
	if String(property).begins_with("settings/"):
		return get_parameter(StringName(String(property).trim_prefix("settings/")))
	return null


func _set(property: StringName, value: Variant) -> bool:
	if String(property).begins_with("settings/"):
		set_parameter(StringName(String(property).trim_prefix("settings/")), value)
		return true
	return false


func _validate_property(property: Dictionary) -> void:
	if property.name == "parameters":
		property.usage = PROPERTY_USAGE_STORAGE
