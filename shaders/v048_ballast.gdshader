shader_type spatial;
render_mode world_vertex_coords;

uniform bool fine_bed = false;
varying vec3 rock_position;
varying float stone_variation;

float mineral_hash(vec3 cell) {
	return fract(sin(dot(cell, vec3(17.31, 47.97, 73.43))) * 43758.55);
}

void vertex() {
	if (fine_bed) {
		VERTEX.y = 10.514 + (VERTEX.y - 10.514) * 0.33;
	}
	rock_position = VERTEX;
	stone_variation = fine_bed ? 0.17 : INSTANCE_CUSTOM.r;
}

void fragment() {
	vec3 mineral_cell = rock_position * 170.0;
	float footprint = max(length(dFdx(mineral_cell)), length(dFdy(mineral_cell)));
	float grain = (mineral_hash(floor(mineral_cell)) - 0.5) * (1.0 - smoothstep(0.72, 1.8, footprint));
	float fleck = mineral_hash(floor(rock_position * 37.0));
	vec3 slate = mix(vec3(0.063, 0.077, 0.107), vec3(0.174, 0.216, 0.282), stone_variation);
	vec3 mineral = mix(slate, vec3(0.191, 0.177, 0.161), smoothstep(0.83, 1.0, stone_variation) * 0.58);
	ALBEDO = mineral * (0.88 + 0.22 * fleck + 0.25 * grain);
	ROUGHNESS = 0.81 + 0.14 * stone_variation;
	SPECULAR = 0.21;
}
