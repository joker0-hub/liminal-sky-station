vec2 volume_span(vec3 origin, vec3 ray, vec3 lower, vec3 upper) {
	vec3 inverse_ray = 1.0 / (ray + vec3(0.000001));
	vec3 a = (lower - origin) * inverse_ray;
	vec3 b = (upper - origin) * inverse_ray;
	vec3 enter = min(a, b);
	vec3 leave = max(a, b);
	return vec2(max(0.0, max(enter.x, max(enter.y, enter.z))), min(leave.x, min(leave.y, leave.z)));
}

float opaque_distance(sampler2D depth_buffer, vec2 uv, mat4 inverse_projection) {
	float depth = texture(depth_buffer, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	depth = depth * 2.0 - 1.0;
#else
	if (depth <= 0.0000001) return 1e20;
#endif
	vec4 view = inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return length(view.xyz / view.w);
}
