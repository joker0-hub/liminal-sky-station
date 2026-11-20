shader_type spatial;
render_mode cull_disabled;

#include "v048_finish_details.gdshaderinc"
#include "compat_color.gdshaderinc"

uniform vec3 dark_pigment;
uniform vec3 light_pigment;
uniform vec3 noise_aspect = vec3(1.0);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D finish_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool textured = false;
uniform float normal_depth = 1.0;
uniform vec3 interior_tint = vec3(1.0);
uniform vec3 track_face_tint = vec3(1.0);
uniform vec3 north_face_tint = vec3(1.0);
uniform float exposed_metal_scale = 1.0;
uniform float edge_finish = 0.0;
uniform float patina_scale = 3.8;
uniform float grain_scale = 115.0;
uniform float roughness_base;
uniform float metalness;
uniform float coat_weight;
uniform float coat_roughness;
uniform float grain_height;
varying vec3 surface_position;
varying vec3 station_position;

void vertex() {
	surface_position = VERTEX;
	station_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 geometric_normal = normalize(NORMAL);
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * geometric_normal);
	vec3 base;
	if (textured) {
		base = texture(albedo_map, UV, -0.20 * edge_finish).rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		base = display_to_linear(base);
#endif
		vec2 finish = texture(finish_map, UV, -0.20 * edge_finish).gb;
		ROUGHNESS = clamp(roughness_base * finish.x, 0.12, 1.0);
		METALLIC = metalness * finish.y;
		NORMAL_MAP = texture(normal_map, UV, -0.12 * edge_finish).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	} else {
		vec3 coordinates = surface_position * noise_aspect;
		float patina = finish_patina(coordinates * patina_scale);
		float grain = filtered_finish_noise(coordinates * grain_scale);
		base = mix(dark_pigment, light_pigment, clamp((patina - 0.20) / 0.61, 0.0, 1.0));
		ROUGHNESS = roughness_base + 0.15 * grain;
		METALLIC = metalness;
		NORMAL = finish_relief(VERTEX, normalize(NORMAL), grain * grain_height);
	}
	// Different exposed faces of the structure retain their own finish.
	float below_deck = 1.0 - smoothstep(10.30, 10.65, station_position.y);
	float outer_roof = smoothstep(12.9, 15.2, station_position.y);
	float rail_side = outer_roof * smoothstep(-3.3, -0.7, station_position.z);
	float north_facade = 1.0 - smoothstep(-4.10, -2.90, station_position.z);
	float track_face = smoothstep(0.03, 0.75, world_normal.z) * max(below_deck, rail_side);
	float north_face = max(smoothstep(0.12, 0.82, -world_normal.z) * max(max(below_deck, outer_roof), north_facade),
		smoothstep(0.28, 0.92, world_normal.y) * outer_roof);
	vec3 tone = mix(interior_tint, track_face_tint, track_face);
	tone = mix(tone, north_face_tint, north_face);
	if (edge_finish > 0.0) {
		// Read the actual bevel and groove normals, and fade subpixel edges.
		vec3 dx = dFdx(VERTEX);
		vec3 dy = dFdy(VERTEX);
		vec3 nx = dFdx(geometric_normal);
		vec3 ny = dFdy(geometric_normal);
		float curvature = 0.5 * (dot(nx, dx) / max(dot(dx, dx), 0.0000001)
			+ dot(ny, dy) / max(dot(dy, dy), 0.0000001));
		float resolved = 1.0 - smoothstep(0.16, 0.51, max(length(nx), length(ny)));
		float bevel = smoothstep(7.0, 39.0, curvature) * resolved * edge_finish;
		float groove = smoothstep(6.0, 32.0, -curvature) * resolved * edge_finish;
		tone *= 1.0 + 0.17 * bevel - 0.15 * groove;
		ROUGHNESS *= 1.0 - 0.19 * bevel;
	}
	ALBEDO = min(base * tone, vec3(1.0));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = linear_to_display(ALBEDO);
#endif
	METALLIC *= mix(1.0, exposed_metal_scale, track_face);
	CLEARCOAT = coat_weight;
	CLEARCOAT_ROUGHNESS = coat_roughness;
}
