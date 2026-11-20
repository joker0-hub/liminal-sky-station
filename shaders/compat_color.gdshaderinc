vec3 linear_to_display(vec3 color) {
	vec3 light = max(color, vec3(0.0));
	vec3 gamma = 1.055 * pow(light, vec3(1.0 / 2.4)) - 0.055;
	return mix(light * 12.92, gamma, step(vec3(0.0031308), light));
}

vec3 display_to_linear(vec3 color) {
	vec3 light = max(color, vec3(0.0));
	vec3 gamma = pow((light + 0.055) / 1.055, vec3(2.4));
	return mix(light / 12.92, gamma, step(vec3(0.04045), light));
}
