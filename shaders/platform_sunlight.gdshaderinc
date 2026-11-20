float sun_shaft(vec3 point, vec3 pane, vec2 half_width, vec3 sun_from, float fade_distance) {
	float travel = (pane.z - point.z) / sun_from.z;
	vec2 projected = abs(point.xy + sun_from.xy * travel - pane.xy);
	vec2 edge = 1.0 - smoothstep(half_width * 0.48, half_width, projected);
	float shaft_length = smoothstep(-0.15, 0.33, travel) * (1.0 - smoothstep(0.95, fade_distance, travel));
	return edge.x * edge.y * shaft_length;
}

float platform_sunlight(vec3 point, vec3 sun_from, float fade_distance) {
	float shafts = sun_shaft(point, vec3(22.30, 18.08, -3.32), vec2(0.60, 0.53), sun_from, fade_distance) * 0.74;
	shafts += sun_shaft(point, vec3(25.07, 14.75, -3.83), vec2(0.65, 0.51), sun_from, fade_distance);
	shafts += sun_shaft(point, vec3(28.83, 14.75, -3.83), vec2(0.55, 0.47), sun_from, fade_distance) * 0.86;
	shafts += sun_shaft(point, vec3(32.59, 14.75, -3.83), vec2(0.62, 0.52), sun_from, fade_distance) * 0.76;
	return shafts;
}
