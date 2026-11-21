shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

#include "volume_rays.gdshaderinc"

uniform sampler2D depth_buffer : hint_depth_texture, filter_nearest;
uniform vec3 volume_min;
uniform vec3 volume_max;
uniform vec3 sun_from;
uniform float window_z;
uniform vec4 panes[4];
varying vec3 box_world_position;

void vertex() {
	box_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Integral of the soft radial density (1 - x*x)^2 across an elliptical beam.
float density_integral(float x) {
	float x2 = x * x;
	return x * (1.0 - x2 * (0.666667 - 0.2 * x2));
}

float shaft_density(vec2 point, vec2 slope, vec2 span, vec4 pane, vec3 origin, vec3 ray) {
	vec2 offset = (point - pane.xy) / pane.zw;
	vec2 motion = slope / pane.zw;
	float rate = max(dot(motion, motion), 0.000001);
	float middle = -dot(offset, motion) / rate;
	vec2 closest = offset + motion * middle;
	float peak = 1.0 - dot(closest, closest);
	if (peak <= 0.0) return 0.0;
	float radius = sqrt(peak / rate);
	vec2 through = vec2(max(span.x, middle - radius), min(span.y, middle + radius));
	if (through.y <= through.x) return 0.0;

	vec2 radial = (through - middle) / radius;
	float integral = peak * peak * radius * (density_integral(radial.y) - density_integral(radial.x));
	float center_z = origin.z + ray.z * mix(through.x, through.y, 0.5);
	float travel = (window_z - center_z) / sun_from.z;
	float taper = smoothstep(0.77, 1.85, travel) * (1.0 - smoothstep(4.6, 12.1, travel));
	return integral * taper;
}

void fragment() {
	vec3 origin = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(box_world_position - origin);
	vec2 span = volume_span(origin, ray, volume_min, volume_max);
	if (span.y <= span.x) discard;
	span.y = min(span.y, opaque_distance(depth_buffer, SCREEN_UV, INV_PROJECTION_MATRIX));
	if (span.y <= span.x) discard;

	vec2 projection = sun_from.xy / sun_from.z;
	vec2 point = origin.xy + projection * (window_z - origin.z);
	vec2 slope = ray.xy - projection * ray.z;
	float scattering = 0.0;
	for (int i = 0; i < 4; i++) {
		scattering += shaft_density(point, slope, span, panes[i], origin, ray);
	}
	float alignment = dot(ray, sun_from);
	float forward_scatter = smoothstep(-0.35, 0.92, alignment);
	float end_on_fade = 1.0 - 0.58 * smoothstep(0.88, 0.995, alignment);
	float opacity = min(0.43, 1.0 - exp(-scattering * mix(0.32, 0.64, forward_scatter))) * end_on_fade;
	if (opacity < 0.003) discard;
	ALBEDO = vec3(1.0, 0.80, 0.52);
	ALPHA = opacity;
}
