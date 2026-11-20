shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D sky_radiance : filter_linear_mipmap, repeat_enable;
uniform float warmth = 0.65;

void fragment() {
	vec3 normal = normalize(NORMAL);
	float facing = clamp(dot(normal, normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	vec3 ray = mat3(INV_VIEW_MATRIX) * reflect(-normalize(VIEW), normal);
	vec2 ray_uv = vec2(0.5 + atan(ray.x, -ray.z) / TAU, 0.5 - asin(clamp(ray.y, -1.0, 1.0)) / PI);
	vec3 reflection = min(textureLod(sky_radiance, ray_uv, 2.4).rgb, vec3(0.66));
	float rim = 1.0 - smoothstep(0.014, 0.072, min(UV.x, 1.0 - UV.x));
	float amber = 0.13 + exp(-5.2 * abs(UV.y - 0.44)) * 0.32;
	ALBEDO = mix(vec3(1.0, 0.64, 0.30) * amber * warmth, reflection, 0.38 + 0.30 * fresnel);
	ALBEDO += vec3(0.16, 0.092, 0.044) * rim;
	ALPHA = 0.070 + 0.125 * fresnel + 0.065 * rim;
}
