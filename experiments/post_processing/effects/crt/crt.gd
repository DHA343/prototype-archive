@tool
class_name CRT
extends PostProcessEffect

enum ChromaticMode {
	FIXED,
	RADIAL,
}

enum MaskModel {
	REDISTRIBUTION,
	CELL_EMISSION,
}

enum MaskPattern {
	STAGGERED_RGB,
	RGB_STRIPES,
	GREEN_MAGENTA_STRIPES,
}

const EFFECT_SHADER: Shader = preload("./crt.gdshader")
const OFFSETS_SHADER: Shader = preload("./image_offsets.gdshader")
const CELL_SHADER: Shader = preload("./phosphor_cells.gdshader")
const SPREAD_SHADER: Shader = preload("./optical_spread.gdshader")
const BLOOM_SHADER: Shader = preload("./phosphor_bloom.gdshader")
const TEXTURE_SHADER: Shader = preload("./crt_texture.gdshader")

@export_group("Chromatic Aberration", "rgb_")
@export_enum("Fixed:0", "Radial:1")
var rgb_mode: int = ChromaticMode.FIXED:
	set(value):
		if value not in ChromaticMode.values() or rgb_mode == value:
			return

		rgb_mode = value
		notify_property_list_changed()
		emit_changed()

## Visible red image offset in output pixels. Positive X / Y moves right / down.
@export_custom(PROPERTY_HINT_RANGE, "-8,8,0.1,suffix:px")
var rgb_red_offset: Vector2 = Vector2(-2.0, 0.5):
	set(value):
		if rgb_red_offset.is_equal_approx(value):
			return

		rgb_red_offset = value
		emit_changed()

## Visible blue image offset relative to green, which stays at the original position.
@export_custom(PROPERTY_HINT_RANGE, "-8,8,0.1,suffix:px")
var rgb_blue_offset: Vector2 = Vector2(2.0, -0.5):
	set(value):
		if rgb_blue_offset.is_equal_approx(value):
			return

		rgb_blue_offset = value
		emit_changed()

## Red image displacement at the screen corners. Positive expands, negative contracts.
@export_range(-8.0, 8.0, 0.1, "suffix:px")
var rgb_red_radial: float = -2.0:
	set(value):
		if is_equal_approx(rgb_red_radial, value):
			return

		rgb_red_radial = value
		emit_changed()

## Blue image displacement at the screen corners; green stays at the original position.
@export_range(-8.0, 8.0, 0.1, "suffix:px")
var rgb_blue_radial: float = 2.0:
	set(value):
		if is_equal_approx(rgb_blue_radial, value):
			return

		rgb_blue_radial = value
		emit_changed()

## Weight of the RGB-separated image relative to the original (weight 1). Zero disables it.
@export_range(0.0, 1.0, 0.01)
var rgb_strength: float = 0.3:
	set(value):
		if is_equal_approx(rgb_strength, value):
			return

		rgb_strength = value
		emit_changed()

@export_group("Signal Reconstruction")
@export var signal_enabled: bool = true:
	set(value):
		if signal_enabled == value:
			return

		signal_enabled = value
		emit_changed()

@export_range(180, 720, 1, "suffix:lines") var scanline_count: int = 360:
	set(value):
		if scanline_count == value:
			return

		scanline_count = value
		emit_changed()

## Average each signal sample's source-pixel area before reconstruction.
## Disable to compare with the previous point-sampled signal.
@export var signal_prefilter_enabled: bool = true:
	set(value):
		if signal_prefilter_enabled == value:
			return

		signal_prefilter_enabled = value
		emit_changed()

@export_range(0.5, 1.0, 0.01) var sharpness: float = 0.67:
	set(value):
		if is_equal_approx(sharpness, value):
			return

		sharpness = value
		emit_changed()

@export_range(0.5, 3.0, 0.1, "suffix:px") var signal_pitch: float = 1.5:
	set(value):
		if is_equal_approx(signal_pitch, value):
			return

		signal_pitch = value
		emit_changed()

## Blend horizontal-only signal with the vertically reconstructed signal.
## Zero keeps vertical detail; one applies the full row reconstruction.
@export_range(0.0, 1.0, 0.01) var vertical_blur: float = 1.0:
	set(value):
		if is_equal_approx(vertical_blur, value):
			return

		vertical_blur = value
		emit_changed()

@export_group("Scanline")
## Row brightness modulation, independent of signal reconstruction. Zero disables it.
@export_range(0.0, 1.0, 0.01) var scanline_strength: float = 0.15:
	set(value):
		if is_equal_approx(scanline_strength, value):
			return

		scanline_strength = value
		emit_changed()

## Full width at half maximum of the row light profile, relative to row spacing.
## Changes the scanline pattern without changing vertical reconstruction.
@export_range(0.75, 1.25, 0.01, "suffix:lines") var beam_width: float = 0.9:
	set(value):
		if is_equal_approx(beam_width, value):
			return

		beam_width = value
		emit_changed()

@export_group("Mask")
## Brightness-dependent color redistribution, or HDR aperture emission.
@export_enum("Mask Redistribution:0", "Cell Emission:1")
var mask_model: int = MaskModel.REDISTRIBUTION:
	set(value):
		if value not in MaskModel.values() or mask_model == value:
			return

		mask_model = value
		notify_property_list_changed()
		emit_changed()

## Staggered RGB alternates by half a period; stripes have no row offset. Both models support all patterns.
@export_enum("Staggered RGB:0", "RGB Stripes:1", "Green / Magenta Stripes:2")
var mask_pattern: int = MaskPattern.STAGGERED_RGB:
	set(value):
		if value not in MaskPattern.values():
			return
		if mask_pattern == value:
			return

		mask_pattern = value
		notify_property_list_changed()
		emit_changed()

## Blend the mask output with the reconstructed signal. Zero removes the mask.
@export_range(0.0, 1.0, 0.01) var mask_strength: float = 0.5:
	set(value):
		if is_equal_approx(mask_strength, value):
			return

		mask_strength = value
		emit_changed()

## Horizontal repeat width in output pixels: one RGB triad, or one G / M pair.
@export_range(2, 6, 1, "suffix:px") var mask_pitch: int = 3:
	set(value):
		if mask_pitch == value:
			return

		mask_pitch = value
		emit_changed()

## Height of each alternating band in Staggered RGB. Stripes do not use this setting.
@export_range(1, 8, 1, "suffix:px") var row_height: int = 3:
	set(value):
		if row_height == value:
			return

		row_height = value
		emit_changed()


@export_group("Texture", "texture_")
@export var texture_enabled: bool = true:
	set(value):
		if texture_enabled == value:
			return

		texture_enabled = value
		emit_changed()

## Fixed brightness variation after the mask, before Optical Spread and Bloom.
## RGB shares one multiplier, from 1 - Strength to 1 + Strength. Zero disables the pass.
@export_range(0.0, 0.5, 0.01) var texture_strength: float = 0.2:
	set(value):
		if is_equal_approx(texture_strength, value):
			return

		texture_strength = value
		emit_changed()

## Spacing of the fixed brightness pattern in output pixels, independent of the mask layout.
@export_range(1.0, 4.0, 0.1, "suffix:px") var texture_size: float = 1.5:
	set(value):
		if is_equal_approx(texture_size, value):
			return

		texture_size = value
		emit_changed()

@export_group("Optical Spread", "optical_spread_")
## Redistribute Mask light to adjacent pixels. Zero disables the pass.
@export_range(0.0, 1.0, 0.01) var optical_spread_strength: float = 0.5:
	set(value):
		if is_equal_approx(optical_spread_strength, value):
			return

		optical_spread_strength = value
		emit_changed()

## Width of the four-sample footprint in output pixels. Zero disables the pass.
@export_range(0.0, 1.0, 0.05, "suffix:px") var optical_spread_width: float = 0.75:
	set(value):
		if is_equal_approx(optical_spread_width, value):
			return

		optical_spread_width = value
		emit_changed()

@export_group("Phosphor Bloom", "phosphor_bloom_")
@export var phosphor_bloom_enabled: bool = true:
	set(value):
		if phosphor_bloom_enabled == value:
			return

		phosphor_bloom_enabled = value
		emit_changed()

@export_range(0.5, 8.0, 0.1, "suffix:px @1080p") var phosphor_bloom_near_width: float = 4.0:
	set(value):
		if is_equal_approx(phosphor_bloom_near_width, value):
			return

		phosphor_bloom_near_width = value
		emit_changed()

@export_range(4.0, 64.0, 0.1, "suffix:px @1080p") var phosphor_bloom_far_width: float = 32.0:
	set(value):
		if is_equal_approx(phosphor_bloom_far_width, value):
			return

		phosphor_bloom_far_width = value
		emit_changed()

@export_range(0.0, 0.25, 0.01) var phosphor_bloom_near_strength: float = 0.1:
	set(value):
		if is_equal_approx(phosphor_bloom_near_strength, value):
			return

		phosphor_bloom_near_strength = value
		emit_changed()

@export_range(0.0, 0.1, 0.001) var phosphor_bloom_far_strength: float = 0.05:
	set(value):
		if is_equal_approx(phosphor_bloom_far_strength, value):
			return

		phosphor_bloom_far_strength = value
		emit_changed()

## Limits Bloom source intensity, without compressing the Core output.
@export_range(1.0, 32.0, 0.1) var phosphor_bloom_hdr_limit: float = 16.0:
	set(value):
		if is_equal_approx(phosphor_bloom_hdr_limit, value):
			return

		phosphor_bloom_hdr_limit = value
		emit_changed()


func _validate_property(property: Dictionary) -> void:
	if property.name in ["rgb_red_offset", "rgb_blue_offset"]:
		if rgb_mode != ChromaticMode.FIXED:
			property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name in ["rgb_red_radial", "rgb_blue_radial"]:
		if rgb_mode != ChromaticMode.RADIAL:
			property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name == "row_height" and mask_pattern != MaskPattern.STAGGERED_RGB:
		property.usage |= PROPERTY_USAGE_READ_ONLY


func get_shader() -> Shader:
	return EFFECT_SHADER


func get_pass_count() -> int:
	return 6


func get_pass_shader(pass_index: int) -> Shader:
	if pass_index == 0:
		return OFFSETS_SHADER
	if pass_index == 1:
		return EFFECT_SHADER
	if pass_index == 2:
		return CELL_SHADER
	if pass_index == 3:
		return TEXTURE_SHADER
	return SPREAD_SHADER if pass_index == 4 else BLOOM_SHADER


func apply_to_pass(material: ShaderMaterial, pass_index: int) -> void:
	if pass_index == 0:
		material.set_shader_parameter(&"rgb_mode", rgb_mode)
		material.set_shader_parameter(&"rgb_red_offset", rgb_red_offset)
		material.set_shader_parameter(&"rgb_blue_offset", rgb_blue_offset)
		material.set_shader_parameter(&"rgb_red_radial", rgb_red_radial)
		material.set_shader_parameter(&"rgb_blue_radial", rgb_blue_radial)
		material.set_shader_parameter(&"rgb_strength", rgb_strength)
		return

	if pass_index == 1:
		apply_to(material)
		return

	if pass_index == 2:
		material.set_shader_parameter(&"mask_pitch", float(mask_pitch))
		material.set_shader_parameter(&"row_height", row_height)
		material.set_shader_parameter(&"mask_pattern", mask_pattern)
		material.set_shader_parameter(&"mask_strength", mask_strength)
		return

	if pass_index == 3:
		material.set_shader_parameter(&"texture_strength", texture_strength)
		material.set_shader_parameter(&"texture_size", texture_size)
		return

	if pass_index == 4:
		material.set_shader_parameter(&"spread_strength", optical_spread_strength)
		material.set_shader_parameter(&"spread_width", optical_spread_width)
		return

	if pass_index == 5:
		material.set_shader_parameter(&"bloom_hdr_limit", phosphor_bloom_hdr_limit)
		material.set_shader_parameter(&"near_strength", phosphor_bloom_near_strength)
		material.set_shader_parameter(&"far_strength", phosphor_bloom_far_strength)
		return


func is_pass_enabled(pass_index: int) -> bool:
	if pass_index == 0:
		var has_chromatic_offset: bool
		if rgb_mode == ChromaticMode.FIXED:
			has_chromatic_offset = rgb_red_offset != Vector2.ZERO or rgb_blue_offset != Vector2.ZERO
		else:
			has_chromatic_offset = rgb_red_radial != 0.0 or rgb_blue_radial != 0.0
		return rgb_strength > 0.0 and has_chromatic_offset
	if pass_index == 1:
		return true
	if pass_index == 2:
		return _is_cell_emission() and mask_strength > 0.0
	if pass_index == 3:
		return texture_enabled and texture_strength > 0.0
	if pass_index == 4:
		return optical_spread_strength > 0.0 and optical_spread_width > 0.0
	if pass_index == 5:
		return (
			phosphor_bloom_enabled
			and (phosphor_bloom_near_strength > 0.0 or phosphor_bloom_far_strength > 0.0)
		)
	return false


func create_pass_source(
	pass_index: int,
	context: PassSourceContext,
	material: ShaderMaterial,
) -> Node:
	if pass_index != 5:
		return null

	var bloom := CRTPhosphorBloom.new()
	bloom.initialize(self, context, material, pass_index)
	return bloom


func _update_shader_parameters() -> void:
	_shader_parameters[&"signal_enabled"] = signal_enabled
	_shader_parameters[&"signal_prefilter_enabled"] = signal_prefilter_enabled
	_shader_parameters[&"scanline_count"] = scanline_count
	_shader_parameters[&"sharpness"] = sharpness
	_shader_parameters[&"signal_pitch"] = signal_pitch
	_shader_parameters[&"vertical_blur"] = vertical_blur
	_shader_parameters[&"scanline_strength"] = scanline_strength
	_shader_parameters[&"beam_width"] = beam_width
	_shader_parameters[&"mask_model"] = mask_model
	_shader_parameters[&"mask_pattern"] = mask_pattern
	_shader_parameters[&"mask_pitch"] = float(mask_pitch)
	_shader_parameters[&"row_height"] = row_height
	_shader_parameters[&"mask_strength"] = mask_strength


func _is_cell_emission() -> bool:
	return mask_model == MaskModel.CELL_EMISSION
