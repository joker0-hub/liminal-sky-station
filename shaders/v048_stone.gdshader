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

vec3 deck_reflection(vec2 screen_uv, vec2 ripples, float blur) {
	vec2 pixel = 1.0 / vec2(textureSize(reflected_scene, 0));
	vec2 uv = vec2(1.0 - screen_uv.x, screen_uv.y) + ripples;
	vec2 offset = pixel * blur;
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
	vec3 position = stone_world_position;
	vec3 normal_world = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec3 reflected_ray = reflect(normalize(position - CAMERA_POSITION_WORLD), normal_world);
	vec3 to_light = raking_lamp_position - position;
	float raking = max(0.0, dot(reflected_ray, normalize(to_light)));
	float lamp_falloff = min(1.0, 121.0 / max(1.0, dot(to_light, to_light)));
	float angle = clamp(dot(normal_world, mat3(INV_VIEW_MATRIX) * normalize(VIEW)), 0.0, 1.0);
	float grazing = pow(1.0 - angle, 2.8);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float grain = filtered_finish_noise(position * 72.0);
	float clusters = finish_patina(position * vec3(15.0, 18.0, 8.0));
	float mineral = mix(clusters, grain, 0.40) - 0.5;
	float quartz = smoothstep(0.59, 0.84, grain) * smoothstep(0.43, 0.64, clusters);
	float vein = (1.0 - smoothstep(0.012, 0.047, abs(clusters - 0.58)))
		* smoothstep(0.50, 0.71, grain);
	float detail = 1.0 + mineral * 0.82 + 0.27 * quartz + 0.21 * vein;
	// The baked water distribution keeps the drier path and wetter window bays.
	float broken_edge = (filtered_finish_noise(position * vec3(8.0, 6.0, 15.0)) - 0.5) * 0.37;
	float wet = smoothstep(0.05, 0.66, surface.g + broken_edge);
	float coat_roughness = mix(clamp(surface.b + 0.12, 0.19, 0.33), 0.09, wet);
	ALBEDO = stone * vec3(0.43, 0.55, 0.77) * detail * mix(1.0, 0.81, wet);
	ROUGHNESS = clamp(surface.r + 0.14 * mineral - 0.15 * wet, 0.18, 0.68);
	CLEARCOAT = 0.88 * wet;
	CLEARCOAT_ROUGHNESS = coat_roughness;
	SPECULAR = mix(0.32, 0.26, wet);
	vec3 glow = (incident * vec3(0.42, 0.50, 0.71) + stone * 0.026) * detail * mix(1.0, 0.83, wet);
	CLEARCOAT *= 0.28;
	CLEARCOAT_ROUGHNESS = max(coat_roughness, 0.30);
	ROUGHNESS = max(ROUGHNESS, 0.36);
	NORMAL = finish_relief(VERTEX, normalize(NORMAL), 0.00068 * (grain + 0.44 * clusters) * mix(1.0, 0.36, wet));
	float lobe = exp2((raking - 1.0) * mix(55.0, 94.0, wet)) * lamp_falloff;
	glow += raking_lamp_color * vec3(1.0, 0.71, 0.41) * lobe * mix(0.13, 0.72, wet);
	if (reflect_deck) {
		float fresnel = mix(0.019 + 0.10 * grazing, 0.074 + 0.54 * grazing, wet);
		vec3 ripple_coords = position * vec3(10.0, 4.0, 19.0);
		vec2 ripples = vec2(filtered_finish_noise(ripple_coords),
			filtered_finish_noise(ripple_coords + vec3(5.3, 2.1, 9.0))) - 0.5;
		vec3 reflected = display_to_linear(deck_reflection(SCREEN_UV,
			ripples * vec2(0.006, 0.011) * wet, 0.22 + coat_roughness * 4.4));
		// Bring out warm highlights in the reflected window light.
		float window_light = smoothstep(0.12, 0.61, reflected.r);
		reflected *= mix(vec3(1.0), vec3(1.55, 1.17, 0.81), window_light);
		glow += reflected * fresnel * smoothstep(0.76, 0.98, normal_world.y);
	}
	// The baked irradiance retains the soft window pattern on the stone.
	ALBEDO = linear_to_display(ALBEDO * 0.57);
	glow = linear_to_display(glow + stone * vec3(0.044, 0.063, 0.086));
#else
	float grain = filtered_finish_noise(position * 66.0);
	float clusters = finish_patina(position * 18.0);
	float mineral = 0.65 * clusters + 0.35 * grain - 0.5;
	float detail = 1.0 + mineral * 0.49;
	ALBEDO = stone * vec3(0.55, 0.55, 0.68) * detail;
	ROUGHNESS = clamp(surface.r + 0.10 * mineral, 0.26, 0.72);
	CLEARCOAT = surface.g;
	CLEARCOAT_ROUGHNESS = surface.b;
	SPECULAR = 0.36;
	NORMAL = finish_relief(VERTEX, normalize(NORMAL), 0.001275 * (grain + 0.28 * clusters));
	vec3 glow = (incident * vec3(0.59, 0.57, 0.68) + stone * 0.036) * detail;
	float lobe = exp2((raking - 1.0) * 36.0) * lamp_falloff;
	glow += raking_lamp_color * lobe * 0.92 * smoothstep(0.79, 0.98, raking);
	if (reflect_deck) {
		float wet = smoothstep(0.0, 0.72, surface.g);
		float fresnel = mix(0.014 + 0.087 * grazing, 0.042 + 0.32 * grazing, wet);
		glow += deck_reflection(SCREEN_UV, vec2(0.0), 0.28 + surface.b * 3.1) * fresnel;
	}
#endif
	EMISSION = glow;
}
