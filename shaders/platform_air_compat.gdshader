shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

#include "volume_rays.gdshaderinc"
#include "platform_sunlight.gdshaderinc"
#include "compat_color.gdshaderinc"

uniform sampler2D depth_buffer : hint_depth_texture, filter_nearest;
uniform vec3 volume_min;
uniform vec3 volume_max;
uniform vec3 sun_from;
varying vec3 box_world_position;

void vertex() {
	box_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 origin = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(box_world_position - origin);
	vec2 interval = volume_span(origin, ray, volume_min, volume_max);
	float start = interval.x;
	float end = min(interval.y, opaque_distance(depth_buffer, SCREEN_UV, INV_PROJECTION_MATRIX));
	if (end <= start) discard;
	const int steps = 20;
	float stride = (end - start) / float(steps);
	float scattering = 0.0;
	for (int i = 0; i < steps; i++) {
		float travel = start + (float(i) + 0.5) * stride;
		vec3 point = origin + ray * travel;
		vec3 edge = min(point - volume_min, volume_max - point);
		float inside = smoothstep(0.0, 0.36, min(edge.x, min(edge.y, edge.z)));
		scattering += platform_sunlight(point, sun_from, 5.2) * inside;
	}
	float opacity = min(0.18, 1.0 - exp(-0.21 * scattering * stride));
	if (opacity < 0.003) discard;
	ALBEDO = linear_to_display(vec3(1.28, 1.03, 0.76));
	ALPHA = opacity;
}
