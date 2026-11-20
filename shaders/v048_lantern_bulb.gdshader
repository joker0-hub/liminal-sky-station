shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float radiance = 1.8;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float diffuse_envelope = smoothstep(0.0, 0.90, facing);
	vec3 honey_edge = vec3(0.68, 0.28, 0.082);
	vec3 warm_core = vec3(1.0, 0.68, 0.34);
	ALBEDO = mix(honey_edge, warm_core, diffuse_envelope) * radiance;
}
