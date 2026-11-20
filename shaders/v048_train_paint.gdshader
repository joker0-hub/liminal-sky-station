shader_type spatial;

#include "cloud_palette.gdshaderinc"
#include "v048_finish_details.gdshaderinc"
#include "compat_color.gdshaderinc"

uniform sampler2D metalwork : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D paint_radiance : filter_linear, repeat_enable;
uniform int paint_part = 0;
varying float railway_height;
varying vec3 paint_coordinates;

void vertex() {
	railway_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	paint_coordinates = VERTEX;
}

float pinstripe(float height, float center, float solid, float edge) {
	return 1.0 - smoothstep(solid, edge, abs(height - center));
}

vec3 paint_ramp(vec3 dark, vec3 light, float factor, float start, float end) {
	return mix(dark, light, clamp((factor - start) / (end - start), 0.0, 1.0));
}

vec3 enamel_reflection(vec3 reflected, float facing, float ivory, float seam) {
	vec2 uv = vec2(0.5 + atan(reflected.x, -reflected.z) / TAU,
		0.5 - asin(clamp(reflected.y, -1.0, 1.0)) / PI);
	vec3 sky = min(texture(paint_radiance, uv).rgb, vec3(1.35));
	float upper = smoothstep(-0.25, 0.26, reflected.y);
	float grazing = pow(1.0 - facing, 3.1);
	// Wide reflections read across the curved enamel without masking the stamped panel lines.
	float ribbon = (1.0 - smoothstep(0.035, 0.185, abs(reflected.y - 0.24)))
		* smoothstep(-0.68, 0.21, reflected.x);
	vec3 highlight = sky * (0.029 + 0.15 * grazing) * mix(0.38, 1.0, upper);
	highlight += vec3(0.40, 0.60, 0.90) * ribbon * (0.050 + 0.13 * grazing);
	return highlight * mix(1.0, 0.63, ivory) * (1.0 - 0.48 * seam);
}

void fragment() {
	if (paint_part > 0 && paint_part <= 3) {
		// V048 paint recipes share the authored seam, rivet and exposed-brass maps.
		bool side = paint_part == 1;
		bool roof = paint_part == 3;
		vec3 detail = texture(metalwork, UV).rgb;
		float patina = finish_patina(paint_coordinates * 6.8);
		float grain = filtered_finish_noise(paint_coordinates * 162.0);
		float height = (1.0 - UV.y) * 2.5 + 0.78;
		float cream = side ? clamp((height - 1.748) / 0.014, 0.0, 1.0) : 0.0;
		float gold = roof ? 0.0 : max(max(pinstripe(height, 1.720, 0.011, 0.014),
			pinstripe(height, 1.638, 0.0085, 0.012)), pinstripe(height, 1.094, 0.008, 0.0115));
		float rivet = clamp((detail.g - 0.05) / 0.19, 0.0, 1.0) * 0.6768;
		float metal = max(max(rivet, detail.b), gold);
		vec3 navy = side
			? paint_ramp(vec3(0.020, 0.079, 0.179), vec3(0.041, 0.135, 0.270), patina, 0.195, 0.75)
			: paint_ramp(vec3(0.017, 0.067, 0.165), vec3(0.034, 0.117, 0.253), patina, 0.195, 0.75);
		vec3 ivory = paint_ramp(vec3(0.719, 0.593, 0.435), vec3(0.878, 0.764, 0.591), patina, 0.24, 0.76);
		vec3 brass = paint_ramp(vec3(0.3515, 0.1441, 0.0331), vec3(0.6939, 0.3712, 0.0823), patina, 0.19, 0.79);
		vec3 paint = mix(mix(navy, ivory, cream), brass, gold);
		paint = mix(paint, vec3(0.00972, 0.01521, 0.02217), detail.r * 0.64);
		paint = mix(paint, paint_ramp(vec3(0.0513, 0.0452, 0.0356), vec3(0.3968, 0.3140, 0.1812),
			patina, 0.20, 0.76), rivet);
		paint = mix(paint, vec3(0.47353, 0.25818, 0.08022), detail.b);
		vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
		float track_face = smoothstep(0.07, 0.87, world_normal.z);
		float front_face = 0.86 * smoothstep(0.12, 0.90, world_normal.x);
		float outward = max(track_face, front_face);
		float top = smoothstep(0.30, 0.92, world_normal.y);
		vec3 shaded_blue = vec3(0.77, 0.82, 0.90);
		vec3 lit_blue = vec3(2.54, 1.85, 1.62);
		vec3 cream_tone = mix(vec3(0.94, 0.95, 0.97), vec3(1.31, 1.26, 1.20), outward);
		vec3 blue_tone = mix(shaded_blue, lit_blue, outward);
		blue_tone = mix(blue_tone, vec3(0.50, 0.56, 0.65), top * 0.86);
		vec3 metal_tone = mix(vec3(1.0), vec3(1.65, 1.78, 1.85), outward);
		ALBEDO = min(paint * mix(mix(blue_tone, cream_tone, cream), metal_tone, metal), vec3(1.0));
		ROUGHNESS = mix(mix(0.255, 0.315, cream) + 0.078 * grain, 0.27, metal);
		METALLIC = mix(0.29, 0.15, cream) + 0.53 * metal;
		float principled_weight = side ? 0.68 + 0.32 * max(cream, metal) : 1.0;
		float ior_level = side ? 0.037 + 0.229 * cream : 0.185;
		// Convert the Principled IOR response at 1.445 to Godot's dielectric F0.
		SPECULAR = sqrt(0.414 * ior_level * principled_weight);
		CLEARCOAT = mix(0.29, 0.19, cream) * principled_weight;
		CLEARCOAT_ROUGHNESS = 0.19;
		vec3 eye = normalize(mat3(INV_VIEW_MATRIX) * VIEW);
		float facing = clamp(dot(world_normal, eye), 0.0, 1.0);
		EMISSION = enamel_reflection(reflect(-eye, world_normal), facing, cream, detail.r)
			+ paint * mix(0.11, 0.09, cream);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ALBEDO = linear_to_display(ALBEDO);
		EMISSION = linear_to_display(EMISSION);
#endif
		float height_map = dot(detail, vec3(-0.39, 0.82, -0.12));
		NORMAL = finish_relief(VERTEX, normalize(NORMAL), 0.0034 * height_map + 0.00045 * grain);
	} else if (paint_part >= 4) {
		float patina = finish_patina(paint_coordinates * 5.4);
		float grain = filtered_finish_noise(paint_coordinates * 95.0);
		bool wheel = paint_part == 5;
		if (wheel) {
			ALBEDO = paint_ramp(vec3(0.1329, 0.1714, 0.2346), vec3(0.3663, 0.4179, 0.4678),
				patina, 0.18, 0.76);
			METALLIC = 0.84;
			ROUGHNESS = mix(0.21, 0.37, grain);
			CLEARCOAT = 0.09;
		} else {
			vec3 iron = paint_ramp(vec3(0.0091, 0.0144, 0.0232), vec3(0.0423, 0.0529, 0.0666),
				patina, 0.20, 0.79);
			float wear = smoothstep(0.49, 0.78, finish_patina(paint_coordinates * 9.3 + 3.1));
			vec3 oxide = mix(vec3(0.0666, 0.0802, 0.0976), vec3(0.3050, 0.2232, 0.1500), grain);
			ALBEDO = mix(iron * 1.24, oxide, wear * 0.57);
			METALLIC = 0.68;
			ROUGHNESS = mix(0.43, 0.62, grain);
			CLEARCOAT = 0.075;
		}
		CLEARCOAT_ROUGHNESS = 0.20;
		NORMAL = finish_relief(VERTEX, normalize(NORMAL), grain * 0.0011);
	} else {
		// The through-gangway panels are also visible from inside the carriage.
		float patina = 0.52 + 0.12 * sin(paint_coordinates.x * 8.5 + cos(paint_coordinates.y * 11.0))
			* sin(paint_coordinates.z * 13.2 - paint_coordinates.y * 5.2);
		float height = (railway_height - 10.7235) * 0.3125;
		float cream = smoothstep(0.54375, 0.5441, height);
		float gold = max(pinstripe(height, 0.3517, 0.00265, 0.0033), pinstripe(height, 0.5168, 0.0027, 0.00325));
		gold = max(gold, pinstripe(height, 0.5402, 0.0034, 0.0039));
		vec3 navy = mix(cloud_color(0.12) * 0.25, cloud_color(0.27) * 0.40, smoothstep(0.0, 0.35, height));
		vec3 ivory = mix(vec3(0.760, 0.628, 0.502), cloud_color(0.98) * 0.90, smoothstep(0.54, 0.99, height));
		ALBEDO = mix(mix(navy, ivory, cream), vec3(0.702, 0.465, 0.209), gold) * (0.84 + patina * 0.28);
		ROUGHNESS = 0.36 + 0.12 * patina;
		METALLIC = 0.08;
		CLEARCOAT = 0.25;
		CLEARCOAT_ROUGHNESS = 0.241;
	}
}
