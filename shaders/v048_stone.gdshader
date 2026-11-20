shader_type spatial;

#include "v048_finish_details.gdshaderinc"
#include "compat_color.gdshaderinc"

uniform sampler2D stone_color : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D stone_surface : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D stone_light : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D reflected_scene : filter_linear, repeat_disable;
uniform bool reflect_deck = false;
uniform vec3 raking_lamp_position;
uniform vec3 raking_lamp_color;
varying vec3 stone_world_position;

void vertex() {
	stone_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 deck_reflection(vec2 screen_uv, float coat_roughness) {
	vec2 uv = vec2(1.0 - screen_uv.x, screen_uv.y);
	vec2 pixel = 1.0 / vec2(textureSize(reflected_scene, 0));
	vec2 offset = pixel * (0.28 + coat_roughness * 3.1);
	vec3 center = texture(reflected_scene, uv).rgb;
	vec3 adjacent = texture(reflected_scene, uv + offset * vec2(1.0, 1.0)).rgb;
	adjacent += texture(reflected_scene, uv + offset * vec2(-1.0, 1.0)).rgb;
	adjacent += texture(reflected_scene, uv + offset * vec2(1.0, -1.0)).rgb;
	adjacent += texture(reflected_scene, uv - offset).rgb;
	return center * 0.55 + adjacent * 0.1125;
}

void fragment() {
	vec3 stone = texture(stone_color, UV).rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	stone = display_to_linear(stone);
#endif
	vec3 incident = max(texture(stone_light, UV).rgb, vec3(0.0));
	vec3 surface = texture(stone_surface, UV).rgb;
	// The station-wide bakes carry the tile colors and wet patches. Real-scale
	// mineral relief keeps the grain visible between the baked texels.
	float grain = filtered_finish_noise(stone_world_position * 66.0);
	float clusters = finish_patina(stone_world_position * 18.0);
	float mineral = 0.65 * clusters + 0.35 * grain - 0.5;
	float detail = 1.0 + mineral * 0.49;
	float roughness = clamp(surface.r + 0.10 * mineral, 0.26, 0.72);
	float coating = surface.g;
	ALBEDO = stone * vec3(0.55, 0.55, 0.68) * detail;
	ROUGHNESS = roughness;
	CLEARCOAT = coating;
	CLEARCOAT_ROUGHNESS = surface.b;
	SPECULAR = 0.36;
	vec3 glow = (incident * vec3(0.59, 0.57, 0.68) + stone * 0.036) * detail;
	vec3 normal_world = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Attenuate fine normals at grazing angles before they reach the specular response.
	float relief_coverage = 1.0 - smoothstep(0.24, 0.70, max(length(dFdx(stone_world_position * 66.0)), length(dFdy(stone_world_position * 66.0))));
	NORMAL = finish_relief(VERTEX, normalize(NORMAL), 0.00057 * relief_coverage * (grain + 0.28 * clusters));
	CLEARCOAT *= 0.35;
	CLEARCOAT_ROUGHNESS = max(CLEARCOAT_ROUGHNESS, 0.34);
	ROUGHNESS = max(ROUGHNESS, 0.40);
	SPECULAR = 0.25;
#else
	NORMAL = finish_relief(VERTEX, normalize(NORMAL), 0.001275 * (grain + 0.28 * clusters));
#endif
	vec3 reflected_ray = reflect(normalize(stone_world_position - CAMERA_POSITION_WORLD), normal_world);
	vec3 to_light = raking_lamp_position - stone_world_position;
	float raking = max(0.0, dot(reflected_ray, normalize(to_light)));
	float lobe = exp2((raking - 1.0) * 36.0) * min(1.0, 121.0 / max(1.0, dot(to_light, to_light)));
	glow += raking_lamp_color * lobe * 0.92 * smoothstep(0.79, 0.98, raking);
	if (reflect_deck) {
		vec3 view_world = mat3(INV_VIEW_MATRIX) * normalize(VIEW);
		float angle = clamp(dot(normal_world, view_world), 0.0, 1.0);
		float grazing = pow(1.0 - angle, 2.8);
		float wet = smoothstep(0.0, 0.72, coating);
		float fresnel = mix(0.014 + 0.087 * grazing, 0.042 + 0.32 * grazing, wet);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		glow += display_to_linear(deck_reflection(SCREEN_UV, max(surface.b, 0.34))) * fresnel * 0.78;
#else
		glow += deck_reflection(SCREEN_UV, surface.b) * fresnel;
#endif
	}
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// The baked irradiance retains the soft window pattern on the stone.
	ALBEDO = linear_to_display(ALBEDO * 0.57);
	glow = linear_to_display(glow + stone * 0.072);
#endif
	EMISSION = glow;
}
