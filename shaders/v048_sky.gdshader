shader_type sky;

#include "compat_color.gdshaderinc"

uniform sampler2D world_map : filter_linear_mipmap, repeat_enable;
uniform float sky_energy = 1.0;
uniform vec3 sun_from;

void sky() {
	vec3 ray = EYEDIR;
	vec2 sky_uv = vec2(0.5 + atan(ray.x, -ray.z) / TAU, 0.5 - asin(clamp(ray.y, -1.0, 1.0)) / PI);
	vec3 balance = mix(vec3(0.82, 0.94, 1.0), vec3(0.55, 0.80, 1.04), smoothstep(-0.08, 0.27, ray.y));
	COLOR = textureLod(world_map, sky_uv, 0.0).rgb * balance * sky_energy;
	float alignment = dot(ray, sun_from);
	float disc = smoothstep(0.999977, 0.999989, alignment);
	float aureole = exp2((alignment - 1.0) * 1650.0);
	COLOR += vec3(1.0, 0.70, 0.44) * (9.0 * disc + 0.16 * aureole);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	COLOR = linear_to_display(COLOR);
#endif
}
