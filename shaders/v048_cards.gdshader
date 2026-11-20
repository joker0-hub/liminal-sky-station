shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

#include "compat_color.gdshaderinc"

uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 balance = vec3(1.0);
uniform float opacity = 1.0;
uniform vec3 matte = vec3(0.42, 0.55, 0.83);
uniform float matte_blend = 0.06;
uniform float side_feather = 0.115;
uniform float bottom_feather = 0.34;
uniform bool sunlit_cloud = true;
uniform bool dusk = false;
varying float cloud_position_z;

void vertex() {
	cloud_position_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec4 ink = texture(artwork, UV);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ink.rgb = display_to_linear(ink.rgb);
#endif
	float from_bottom = 1.0 - UV2.y;
	float ends = smoothstep(0.0, side_feather, min(UV2.x, 1.0 - UV2.x));
	float base = smoothstep(0.0, bottom_feather, from_bottom);
	float top = 1.0 - smoothstep(0.94, 1.0, from_bottom);
	float coverage = smoothstep(0.065, 0.960, ink.a) * opacity * ends * base * top;
	if (coverage < 0.008) discard;
	vec3 pigment = mix(ink.rgb, matte, matte_blend);
	if (sunlit_cloud) {
		float facing_sunset = mix(0.22, 0.68, smoothstep(-190.0, 370.0, -cloud_position_z));
		float cloud_edge = smoothstep(0.23, 0.92, dot(pigment, vec3(0.2126, 0.7152, 0.0722)));
		pigment *= dusk
			? 1.04 * mix(vec3(1.0), vec3(1.02, 0.84, 0.70), cloud_edge * mix(0.46, 0.72, facing_sunset))
			: 1.07 * mix(vec3(1.0), vec3(1.12, 1.01, 0.92), facing_sunset * cloud_edge * 0.40);
	}
	vec3 color = pigment * balance;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	color = linear_to_display(color);
#endif
	ALBEDO = color;
	ALPHA = coverage;
}
