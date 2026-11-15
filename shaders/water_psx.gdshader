shader_type spatial;
// Вода Embers of the Spire: тиха течія, дві шари брижів, фальшиве відображення неба,
// блік місяця/сонця, піна біля берегів (за глибиною) та постеризація під PS1.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.02, 0.07, 0.09, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.09, 0.24, 0.25, 1.0);
uniform vec4 foam_color : source_color = vec4(0.62, 0.76, 0.76, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.14, 0.17, 0.27, 1.0);
uniform vec4 sky_zenith : source_color = vec4(0.02, 0.03, 0.08, 1.0);
uniform vec4 light_color : source_color = vec4(0.7, 0.8, 1.0, 1.0);
uniform vec3 light_dir = vec3(-0.68, 0.5, -0.54);
uniform float brightness = 0.55;
uniform float flow_speed = 0.45;
uniform float ripple_scale = 0.85;
uniform float steps = 28.0;
uniform float swirl = 0.0;
uniform float shore_depth = 0.3;
uniform float foam_depth = 0.05;
uniform bool edge_fade = true;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;
varying vec2 flow_dir;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float height_at(vec2 p, vec2 flow, float t) {
	vec2 uv1 = p * ripple_scale - flow * t;
	vec2 uv2 = p * ripple_scale * 2.3 - flow * t * 0.6 + vec2(17.0, 5.0);
	return vnoise(uv1) * 0.65 + vnoise(uv2) * 0.35;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_dir = COLOR.rg * 2.0 - 1.0;
}

void fragment() {
	vec2 flow = flow_dir * flow_speed;
	// Озеро: повільний вихор навколо центру (flow = 0, swirl > 0).
	flow += swirl * vec2(-sin(world_pos.z * 0.05), cos(world_pos.x * 0.05)) * 0.2;
	float t = TIME;
	float e = 0.2;
	float h0 = height_at(world_pos.xz, flow, t);
	float hx = height_at(world_pos.xz + vec2(e, 0.0), flow, t);
	float hz = height_at(world_pos.xz + vec2(0.0, e), flow, t);
	vec3 n = normalize(vec3((h0 - hx) * 1.1, 0.4, (h0 - hz) * 1.1));
	vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 refl = reflect(-view_w, n);
	float fres = pow(1.0 - clamp(dot(n, view_w), 0.0, 1.0), 4.0);
	fres = clamp(0.06 + fres * 0.6, 0.0, 0.7);

	// Глибина під поверхнею: мілина прозоріша й світліша, береги піняться.
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene.xyz /= scene.w;
	float depth_diff = max(-scene.z + VERTEX.z, 0.0);
	float shore = smoothstep(0.0, shore_depth, depth_diff);

	vec3 body = mix(shallow_color.rgb, deep_color.rgb, shore) * brightness;
	vec3 sky = mix(sky_horizon.rgb, sky_zenith.rgb, clamp(refl.y * 1.4, 0.0, 1.0));
	// Відображення брижить небо: легкі «смуги» світла вздовж течії.
	float glints = smoothstep(0.7, 0.95, h0 + (hx - h0) * 2.0) * 0.25;
	vec3 col = mix(body, sky * (0.7 + glints), fres);
	float spec = pow(max(dot(refl, normalize(light_dir)), 0.0), 140.0);
	col += light_color.rgb * spec * 1.6;
	float foam_n = vnoise(world_pos.xz * 1.4 - flow * t * 0.8);
	float foam = (1.0 - smoothstep(0.0, foam_depth, depth_diff)) * smoothstep(0.25, 0.7, foam_n + 0.25) * 0.8;
	foam += smoothstep(0.82, 0.97, h0) * 0.08;
	col = mix(col, foam_color.rgb * (0.4 + brightness), clamp(foam, 0.0, 1.0));

	col = floor(col * steps + 0.5) / steps;
	ALBEDO = col;
	float alpha = clamp(mix(0.55, 0.93, shore) + foam * 0.3, 0.0, 0.97);
	if (edge_fade) {
		alpha *= 1.0 - smoothstep(0.55, 1.0, abs(UV.x * 2.0 - 1.0));
	}
	ALPHA = alpha;
}
