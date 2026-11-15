// Тіло PSX-матеріалу. Підключається з psx_lit.gdshader та psx_lit_alpha.gdshader.
#include "res://shaders/psx_common.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform sampler2D detail_texture : source_color, filter_nearest, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float detail_gain = 1.22;
uniform float texel_density = 0.5;   // повторів текстури на метр
uniform bool world_space_detail = true;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float specular_value : hint_range(0.0, 1.0) = 0.2;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

varying vec3 v_detail_pos;
varying vec3 v_detail_nrm;

void vertex() {
	if (world_space_detail) {
		v_detail_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_detail_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	} else {
		v_detail_pos = VERTEX;
		v_detail_nrm = NORMAL;
	}
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec4 base = albedo_color;
	if (use_albedo_texture) {
		base *= texture(albedo_texture, UV * uv_scale);
	}
	vec2 duv = psx_planar_uv(v_detail_pos * texel_density, v_detail_nrm);
	vec3 detail = texture(detail_texture, duv).rgb * detail_gain;
	base.rgb *= mix(vec3(1.0), detail, detail_strength);

	ALBEDO = base.rgb;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	EMISSION = emission_color.rgb * emission_energy;
#ifdef PSX_ALPHA
	ALPHA = base.a;
#endif
}
