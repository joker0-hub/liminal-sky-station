vec3 cloud_color(float tone) {
	// Linear colors sampled from the opaque regions of the source E01 cloud artwork.
	const vec3 shade = vec3(0.125, 0.212, 0.491);
	const vec3 blue = vec3(0.178, 0.258, 0.546);
	const vec3 lilac = vec3(0.275, 0.314, 0.565);
	const vec3 pink = vec3(0.565, 0.407, 0.507);
	const vec3 peach = vec3(0.956, 0.610, 0.412);
	const vec3 cream = vec3(0.982, 0.913, 0.665);
	vec3 color = mix(shade, blue, smoothstep(0.00, 0.24, tone));
	color = mix(color, lilac, smoothstep(0.16, 0.38, tone));
	color = mix(color, pink, smoothstep(0.31, 0.59, tone));
	color = mix(color, peach, smoothstep(0.50, 0.79, tone));
	return mix(color, cream, smoothstep(0.72, 1.00, tone));
}
