shader_type fog;

#include "platform_sunlight.gdshaderinc"

uniform vec3 sun_from;

void fog() {
	float edges = 1.0 - smoothstep(-0.36, 0.0, SDF);
	// Pane centers in the imported main arch and east canopy. The shadow map
	// still clips the light at the steelwork and moving train.
	DENSITY = 0.038 * platform_sunlight(WORLD_POSITION, sun_from, 3.0) * edges;
	ALBEDO = vec3(0.96, 0.94, 0.89);
}
