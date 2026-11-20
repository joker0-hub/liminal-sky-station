shader_type spatial;
render_mode cull_disabled;

#include "cloud_palette.gdshaderinc"

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D finish_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_map = false;
uniform bool has_finish_map = false;
uniform bool has_normal_map = false;
uniform float roughness_factor = 0.5;
uniform float metallic_factor = 0.0;
uniform float normal_depth = 0.55;
uniform float brightness = 1.0;
uniform float palette_mix = 0.45;
uniform vec2 palette_range = vec2(0.12, 0.45);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
	vec3 base = base_color.rgb;
	if (has_albedo_map) {
		base *= texture(albedo_map, UV).rgb;
	}
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	float sky_facing = clamp(world_normal.y * 0.38 + 0.54, 0.0, 1.0);
	float pigment = sin(dot(world_position, vec3(2.14, 1.16, -0.83)))
		* sin(dot(world_position, vec3(-0.47, 1.39, 1.28)));
	float tone = mix(palette_range.x, palette_range.y, sky_facing + 0.065 * pigment);
	vec3 palette_color = cloud_color(tone);
	vec3 graded = palette_color * (dot(base, luma) / dot(palette_color, luma));
	ALBEDO = mix(base, graded, palette_mix) * brightness;
	ROUGHNESS = roughness_factor;
	METALLIC = metallic_factor;
	if (has_finish_map) {
		vec2 finish = texture(finish_map, UV).gb;
		ROUGHNESS *= finish.x;
		METALLIC *= finish.y;
	}
	ROUGHNESS = clamp(ROUGHNESS + 0.04 * pigment, 0.26, 0.89);
	if (has_normal_map) {
		NORMAL_MAP = texture(normal_map, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
}
