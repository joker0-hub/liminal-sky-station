float finish_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float finish_noise(vec3 position) {
	vec3 cell = floor(position);
	vec3 f = fract(position);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(finish_hash(cell), finish_hash(cell + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(finish_hash(cell + vec3(0.0, 1.0, 0.0)), finish_hash(cell + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(finish_hash(cell + vec3(0.0, 0.0, 1.0)), finish_hash(cell + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(finish_hash(cell + vec3(0.0, 1.0, 1.0)), finish_hash(cell + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float filtered_finish_noise(vec3 position) {
	float footprint = max(length(dFdx(position)), length(dFdy(position)));
	return mix(finish_noise(position), 0.5, smoothstep(0.30, 1.0, footprint));
}

float finish_patina(vec3 position) {
	return filtered_finish_noise(position) * 0.62
		+ filtered_finish_noise(position * 2.0 + vec3(1.7, 5.3, 2.9)) * 0.26
		+ filtered_finish_noise(position * 4.0 + vec3(8.1, 2.6, 3.7)) * 0.12;
}

vec3 finish_relief(vec3 position, vec3 normal, float height) {
	vec3 dpdx = dFdx(position);
	vec3 dpdy = dFdy(position);
	vec3 tx = cross(dpdy, normal);
	vec3 ty = cross(normal, dpdx);
	float determinant = dot(dpdx, tx);
	vec3 gradient = sign(determinant) * (dFdx(height) * tx + dFdy(height) * ty);
	return normalize(max(abs(determinant), 0.00000001) * normal - gradient);
}
