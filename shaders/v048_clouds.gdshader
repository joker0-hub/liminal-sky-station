shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

#include "cloud_palette.gdshaderinc"
#include "volume_rays.gdshaderinc"
#include "compat_color.gdshaderinc"

uniform sampler3D cloud_field : filter_linear, repeat_disable;
uniform sampler2D depth_buffer : hint_depth_texture, filter_nearest;
uniform vec3 cloud_min;
uniform vec3 cloud_max;
uniform float authored_density_max = 1.2;
uniform float extinction = 1.31;
uniform float brightness = 1.0;
uniform int march_steps = 124;
varying vec3 box_world_position;

void vertex() {
	box_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 origin = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(box_world_position - origin);
	vec2 interval = volume_span(origin, ray, cloud_min, cloud_max);
	float start = interval.x;
	if (interval.y <= start) discard;
	float end = min(interval.y, opaque_distance(depth_buffer, SCREEN_UV, INV_PROJECTION_MATRIX) - 0.05);
	if (end <= start) discard;

	float stride = max(0.38, (end - start) / float(march_steps));
	// A fixed spatial offset breaks up long parallel steps without temporal noise.
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float distance_along_ray = start + stride * (0.17 + 0.66 * dither);
	vec3 inverse_span = 1.0 / (cloud_max - cloud_min);
	vec3 uvw = (origin + distance_along_ray * ray - cloud_min) * inverse_span;
	vec3 uv_step = ray * stride * inverse_span;
	float absorption = authored_density_max * extinction * stride;
	float transmission = 1.0;
	float illumination = 0.0;
	float elevation = 0.0;
	for (int step_index = 0; step_index < march_steps; step_index++) {
		if (distance_along_ray > end || transmission < 0.009) break;
		vec2 data = textureLod(cloud_field, uvw, 0.0).rg;
		if (data.r > 0.0) {
			float contribution = transmission * (1.0 - exp(-data.r * absorption));
			illumination += contribution * data.g;
			elevation += contribution * uvw.y;
			transmission -= contribution;
		}
		distance_along_ray += stride;
		uvw += uv_step;
	}
	float alpha = 1.0 - transmission;
	if (alpha < 0.002) discard;
	float sky_fill = smoothstep(0.27, 0.94, elevation / alpha);
	float tone = clamp(1.28 * illumination / alpha + 0.105 * sky_fill - 0.13, 0.0, 1.0);
	vec3 color = cloud_color(tone) * (1.10 + 0.32 * tone) * brightness;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	color = linear_to_display(color);
#endif
	ALBEDO = color;
	ALPHA = alpha;
}
