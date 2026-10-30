@tool
extends ExperimentEffect

const EFFECT_SHADER: Shader = preload("vhs.gdshader")
const PARAMETER_GROUPS: Dictionary = {
	"Playback": [&"speed", &"frame_rate", &"signal_lines"],
	"Luma": [&"luma_blur"],
	"Chroma": [&"radius", &"chroma_offset", &"saturation"],
	"Time Base": [&"amount", &"row_group_size", &"time_smoothing"],
	"Dropout": [&"dropout_amount", &"dropout_length", &"dropout_shift"],
}
const PARAMETER_UNITS: Dictionary = {
	&"frame_rate": "fps",
	&"signal_lines": "lines",
	&"luma_blur": "px",
	&"radius": "px",
	&"chroma_offset": "px",
	&"row_group_size": "px",
	&"dropout_length": "px",
	&"dropout_shift": "px",
}


func get_shader() -> Shader:
	return EFFECT_SHADER


func _get_parameter_properties() -> Array[Dictionary]:
	var uniforms: Dictionary = {}
	for property: Dictionary in super._get_parameter_properties():
		uniforms[property.name] = property
	var properties: Array[Dictionary] = []
	for group: String in PARAMETER_GROUPS:
		properties.append({
			"name": group,
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
			"hint_string": "settings/",
		})
		for parameter: StringName in PARAMETER_GROUPS[group]:
			var property: Dictionary = uniforms["settings/" + String(parameter)]
			if PARAMETER_UNITS.has(parameter):
				property.hint_string += ",suffix:" + PARAMETER_UNITS[parameter]
			properties.append(property)
	return properties
