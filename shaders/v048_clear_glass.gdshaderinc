#include "compat_color.gdshaderinc"

uniform sampler2D sky_radiance : filter_linear_mipmap, repeat_enable;
uniform float face_reflectance = 0.032;
uniform float grazing_reflectance = 0.24;
uniform float reflection_roughness = 1.35;
uniform bool authored_station_glass = false;
uniform bool canopy_glass = false;
uniform bool web_glazing = false;

float glass_fresnel(float facing, float index_of_refraction) {
	float transmitted = sqrt(1.0 - (1.0 - facing * facing) / (index_of_refraction * index_of_refraction));
	float perpendicular = (facing - index_of_refraction * transmitted) / (facing + index_of_refraction * transmitted);
	float parallel = (index_of_refraction * facing - transmitted) / (index_of_refraction * facing + transmitted);
	return 0.5 * (perpendicular * perpendicular + parallel * parallel);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 eye = normalize(VIEW);
	float facing = clamp(abs(dot(normal, eye)), 0.0, 1.0);
	float grazing = pow(1.0 - facing, 5.0);
	vec3 ray = mat3(INV_VIEW_MATRIX) * reflect(-eye, normal);
	vec2 uv = vec2(0.5 + atan(ray.x, -ray.z) / TAU, 0.5 - asin(clamp(ray.y, -1.0, 1.0)) / PI);
	vec3 reflection = min(textureLod(sky_radiance, uv, reflection_roughness).rgb, vec3(1.4));
	if (authored_station_glass) {
		float sheen = pow(max(0.0, dot(ray, normalize(vec3(-0.69, 0.45, -0.56)))), 15.0);
		vec3 reflected_sky = reflection * vec3(0.80, 0.96, 1.09);
		if (web_glazing) {
			ALBEDO = reflected_sky * vec3(0.82, 1.02, 1.18) + vec3(0.12, 0.26, 0.44)
				+ vec3(0.35, 0.28, 0.18) * sheen;
			float falloff = 1.0 - facing;
			ALPHA = (canopy_glass ? 0.105 : 0.088) + 0.27 * falloff * falloff + 0.065 * sheen;
		} else {
			float fresnel = glass_fresnel(facing, 1.45);
			ALBEDO = reflected_sky + vec3(0.26, 0.23, 0.17) * sheen;
			ALPHA = canopy_glass ? 0.060 + 0.18 * pow(1.0 - facing, 2.9) + 0.040 * sheen
				: min(0.25, 0.046 + 0.34 * fresnel + 0.047 * sheen);
		}
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ALBEDO = linear_to_display(ALBEDO);
#endif
	} else {
		ALBEDO = reflection * vec3(0.86, 0.96, 1.06);
		ALPHA = face_reflectance + grazing_reflectance * grazing;
	}
}
