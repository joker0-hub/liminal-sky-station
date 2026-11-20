shader_type spatial;

#include "v048_finish_details.gdshaderinc"

uniform sampler2D original_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float saturation = 1.0;
uniform float roughness_base;
uniform float grain_scale;
uniform float grain_height;
uniform float metalness;
uniform float coat_weight;

instance uniform vec3 generated_origin = vec3(0.0);
instance uniform vec3 generated_size = vec3(1.0);
varying vec3 generated_position;

void vertex() {
	generated_position = (VERTEX - generated_origin) / max(generated_size, vec3(0.0001));
}

void fragment() {
	vec3 color = texture(original_albedo, UV, -0.20).rgb;
	float peak = max(color.r, max(color.g, color.b));
	float grain = finish_patina(generated_position * grain_scale);
	ALBEDO = max(vec3(0.0), peak - (peak - color) * saturation);
	ROUGHNESS = roughness_base + 0.18 * grain;
	METALLIC = metalness;
	CLEARCOAT = coat_weight;
	CLEARCOAT_ROUGHNESS = 0.25;
	NORMAL = finish_relief(VERTEX, normalize(NORMAL), grain * grain_height);
}
